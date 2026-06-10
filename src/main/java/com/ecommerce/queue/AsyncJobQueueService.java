package com.ecommerce.queue;

import com.ecommerce.service.InvoiceService;
import com.ecommerce.service.NotificationService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class AsyncJobQueueService {

    private static final String TYPE_INVOICE = "INVOICE";
    private static final String TYPE_ORDER_CONFIRMATION = "ORDER_CONFIRMATION";
    private static final String TYPE_LOW_STOCK = "LOW_STOCK";

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final InvoiceService invoiceService;
    private final NotificationService notificationService;

    @Value("${queue.async.ready-key:ecommerce:queue:async-jobs}")
    private String readyKey;

    @Value("${queue.async.failed-key:ecommerce:queue:async-jobs:failed}")
    private String failedKey;

    public void enqueueInvoiceJob(String orderId, String email, double amount) {
        enqueue(AsyncJob.builder()
                .type(TYPE_INVOICE)
                .orderId(orderId)
                .email(email)
                .amount(amount)
                .createdAt(LocalDateTime.now().toString())
                .build());
    }

    public void enqueueOrderConfirmationJob(String email, String orderId) {
        enqueue(AsyncJob.builder()
                .type(TYPE_ORDER_CONFIRMATION)
                .orderId(orderId)
                .email(email)
                .createdAt(LocalDateTime.now().toString())
                .build());
    }

    public void enqueueLowStockJob(String productName, int currentQuantity) {
        enqueue(AsyncJob.builder()
                .type(TYPE_LOW_STOCK)
                .productName(productName)
                .quantity(currentQuantity)
                .createdAt(LocalDateTime.now().toString())
                .build());
    }

    private void enqueue(AsyncJob job) {
        try {
            String payload = objectMapper.writeValueAsString(job);
            redisTemplate.opsForList().rightPush(readyKey, payload);
            log.info("[REDIS-QUEUE] job-enqueued | type={} | readyKey={}", job.getType(), readyKey);
        } catch (Exception ex) {
            log.error("[REDIS-QUEUE] enqueue-failed | type={} | error={}", job.getType(), ex.getMessage(), ex);
            throw new IllegalStateException("Could not enqueue async job", ex);
        }
    }

    @Scheduled(fixedDelayString = "${queue.async.worker-delay-ms:1000}")
    public void processNextJob() {
        String payload = redisTemplate.opsForList().leftPop(readyKey);

        if (payload == null) {
            return;
        }

        try {
            AsyncJob job = objectMapper.readValue(payload, AsyncJob.class);
            process(job);
            log.info("[REDIS-QUEUE] job-processed | type={}", job.getType());
        } catch (Exception ex) {
            redisTemplate.opsForList().rightPush(failedKey, payload);
            log.error("[REDIS-QUEUE] job-failed | failedKey={} | error={}", failedKey, ex.getMessage(), ex);
        }
    }

    private void process(AsyncJob job) {
        switch (job.getType()) {
            case TYPE_INVOICE -> invoiceService.generateInvoice(job.getOrderId(), job.getEmail(), job.getAmount());
            case TYPE_ORDER_CONFIRMATION -> notificationService.sendOrderConfirmation(job.getEmail(), job.getOrderId());
            case TYPE_LOW_STOCK -> notificationService.sendLowStockAlert(job.getProductName(), job.getQuantity());
            default -> throw new IllegalArgumentException("Unsupported async job type: " + job.getType());
        }
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class AsyncJob {
        private String type;
        private String orderId;
        private String email;
        private Double amount;
        private String productName;
        private Integer quantity;
        private String createdAt;
    }
}