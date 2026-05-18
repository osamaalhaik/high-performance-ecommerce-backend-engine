package com.ecommerce.service;

import com.ecommerce.dto.OrderDTOs;
import com.ecommerce.entity.*;
import com.ecommerce.exception.InsufficientStockException;
import com.ecommerce.exception.ResourceNotFoundException;
import com.ecommerce.repository.OrderRepository;
import com.ecommerce.repository.PaymentRepository;
import com.ecommerce.repository.ProductRepository;
import com.ecommerce.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;

import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final PaymentRepository paymentRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final InvoiceService invoiceService;
    private final CacheManager cacheManager;

    @Transactional(
            isolation = Isolation.READ_COMMITTED,
            rollbackFor = Exception.class
    )
    public OrderDTOs.OrderResponse placeOrder(String userId, OrderDTOs.CreateOrderRequest request) {

        User user = userRepository.findById(userId)
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

            if (product.getStockQuantity() < requestedQuantity) {
                throw new InsufficientStockException(
                        "Insufficient stock for product: " + product.getName()
                                + ". Available=" + product.getStockQuantity()
                                + ", requested=" + requestedQuantity
                );
            }

            product.setStockQuantity(product.getStockQuantity() - requestedQuantity);
            productRepository.save(product);
            evictProductCache(productId);

            OrderItem item = OrderItem.builder()
                    .product(product)
                    .quantity(requestedQuantity)
                    .unitPrice(product.getPrice())
                    .build();

            orderItems.add(item);
            totalAmount += item.getSubtotal();
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

        log.info(
                "[ORDER] Order confirmed | order={} | user={} | total={} | items={}",
                savedOrder.getId(),
                userId,
                totalAmount,
                orderItems.size()
        );

        invoiceService.generateInvoiceAsync(savedOrder.getId(), user.getEmail(), totalAmount);
        notificationService.sendOrderConfirmationAsync(user.getEmail(), savedOrder.getId());

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

    private void evictProductCache(String productId) {
        Cache productsCache = cacheManager.getCache("products");

        if (productsCache != null) {
            productsCache.evict(productId);
            log.debug("[CACHE] Evicted product cache after stock update: {}", productId);
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