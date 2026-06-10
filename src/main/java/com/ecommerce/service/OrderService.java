package com.ecommerce.service;

import com.ecommerce.dto.OrderDTOs;
import com.ecommerce.entity.*;
import com.ecommerce.exception.BusinessException;
import com.ecommerce.exception.InsufficientStockException;
import com.ecommerce.exception.ResourceNotFoundException;
import com.ecommerce.queue.AsyncJobQueueService;
import com.ecommerce.repository.OrderRepository;
import com.ecommerce.repository.PaymentRepository;
import com.ecommerce.repository.ProductRepository;
import com.ecommerce.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private static final int LOW_STOCK_THRESHOLD = 5;

    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final PaymentRepository paymentRepository;
    private final UserRepository userRepository;
    private final AsyncJobQueueService asyncJobQueueService;
    private final CacheManager cacheManager;

    @Transactional(
            isolation = Isolation.READ_COMMITTED,
            rollbackFor = Exception.class
    )
    public OrderDTOs.OrderResponse placeOrder(String userId, OrderDTOs.CreateOrderRequest request) {

        User user = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Map<String, Integer> mergedItems = mergeDuplicateProducts(request.getItems());

        List<String> sortedProductIds = mergedItems.keySet()
                .stream()
                .sorted()
                .toList();

        List<OrderItem> orderItems = new ArrayList<>();
        double totalAmount = 0.0;

        for (String productId : sortedProductIds) {

            int requestedQuantity = mergedItems.get(productId);

            Product product = productRepository.findByIdForUpdate(productId)
                    .orElseThrow(() -> new ResourceNotFoundException(
                            "Product not found: " + productId
                    ));

            log.debug("[SYNC] Product locked for stock update | product={} | stock={} | requested={}",
                    product.getId(),
                    product.getStockQuantity(),
                    requestedQuantity
            );

            if (product.getStockQuantity() < requestedQuantity) {
                throw new InsufficientStockException(
                        "Insufficient stock for product: " + product.getName()
                                + ". Available=" + product.getStockQuantity()
                                + ", requested=" + requestedQuantity
                );
            }

            OrderItem item = OrderItem.builder()
                    .product(product)
                    .quantity(requestedQuantity)
                    .unitPrice(product.getPrice())
                    .build();

            orderItems.add(item);
            totalAmount += item.getSubtotal();
        }

        log.debug("[SYNC] User wallet locked for payment | user={} | wallet={} | required={}",
                user.getId(),
                user.getWalletBalance(),
                totalAmount
        );

        if (user.getWalletBalance() < totalAmount) {
            throw new BusinessException(
                    "Insufficient wallet balance. Available="
                            + user.getWalletBalance()
                            + ", required="
                            + totalAmount
            );
        }

        simulatePaymentGatewayDelay();

        user.setWalletBalance(user.getWalletBalance() - totalAmount);
        userRepository.save(user);

        for (OrderItem item : orderItems) {
            Product product = item.getProduct();
            product.setStockQuantity(product.getStockQuantity() - item.getQuantity());
            productRepository.save(product);
            evictCache("products", product.getId());

            if (product.getStockQuantity() <= LOW_STOCK_THRESHOLD) {
                asyncJobQueueService.enqueueLowStockJob(product.getName(), product.getStockQuantity());
            }
        }

        Order order = Order.builder()
                .user(user)
                .totalAmount(totalAmount)
                .status(Order.OrderStatus.CONFIRMED)
                .build();

        Order savedOrder = orderRepository.save(order);

        for (OrderItem item : orderItems) {
            item.setOrder(savedOrder);
        }

        savedOrder.setItems(orderItems);
        savedOrder = orderRepository.save(savedOrder);

        Payment payment = Payment.builder()
                .order(savedOrder)
                .amount(totalAmount)
                .status(Payment.PaymentStatus.SUCCESS)
                .transactionRef("TXN-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .processedAt(LocalDateTime.now())
                .build();

        paymentRepository.save(payment);
        savedOrder.setPayment(payment);

        evictCache("admin-stats", "last24h");

        log.info(
                "[ORDER] Order confirmed | order={} | user={} | total={} | remainingWallet={} | items={}",
                savedOrder.getId(),
                userId,
                totalAmount,
                user.getWalletBalance(),
                orderItems.size()
        );

        asyncJobQueueService.enqueueInvoiceJob(savedOrder.getId(), user.getEmail(), totalAmount);
        asyncJobQueueService.enqueueOrderConfirmationJob(user.getEmail(), savedOrder.getId());

        return buildOrderResponse(savedOrder, "Order placed successfully");
    }

    @Transactional(readOnly = true)
    public List<OrderDTOs.OrderResponse> getUserOrders(String userId) {
        return orderRepository.findByUserId(userId)
                .stream()
                .map(order -> buildOrderResponse(order, null))
                .toList();
    }

    private Map<String, Integer> mergeDuplicateProducts(List<OrderDTOs.OrderItemRequest> items) {

        Map<String, Integer> merged = new HashMap<>();

        for (OrderDTOs.OrderItemRequest item : items) {
            merged.merge(
                    item.getProductId(),
                    item.getQuantity(),
                    Integer::sum
            );
        }

        return merged;
    }

    private void simulatePaymentGatewayDelay() {
        try {
            Thread.sleep(1200);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new BusinessException("Payment simulation interrupted");
        }
    }

    private void evictCache(String cacheName, String key) {
        Cache cache = cacheManager.getCache(cacheName);

        if (cache != null) {
            cache.evict(key);
            log.debug("[CACHE] Evicted cache | cache={} | key={}", cacheName, key);
        }
    }

    private OrderDTOs.OrderResponse buildOrderResponse(Order order, String message) {

        List<OrderDTOs.OrderItemResponse> itemResponses = order.getItems() == null
                ? List.of()
                : order.getItems()
                .stream()
                .map(item -> OrderDTOs.OrderItemResponse.builder()
                        .productId(item.getProduct().getId())
                        .productName(item.getProduct().getName())
                        .quantity(item.getQuantity())
                        .unitPrice(item.getUnitPrice())
                        .subtotal(item.getSubtotal())
                        .build())
                .toList();

        return OrderDTOs.OrderResponse.builder()
                .orderId(order.getId())
                .status(order.getStatus().name())
                .totalAmount(order.getTotalAmount())
                .items(itemResponses)
                .createdAt(order.getCreatedAt())
                .message(message)
                .build();
    }
}