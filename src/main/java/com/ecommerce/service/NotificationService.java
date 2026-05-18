package com.ecommerce.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
@Slf4j
public class NotificationService {

    @Async("taskExecutor")
    public CompletableFuture<Void> sendOrderConfirmationAsync(String email, String orderId) {
        log.info("[ASYNC-NOTIFICATION] Sending confirmation email | email={} | order={} | thread={}",
                email, orderId, Thread.currentThread().getName());

        try {
            Thread.sleep(500);
            log.info("[ASYNC-NOTIFICATION] Confirmation email sent | email={} | order={}", email, orderId);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            log.error("[ASYNC-NOTIFICATION] Interrupted while sending email", ex);
        }

        return CompletableFuture.completedFuture(null);
    }

    @Async("taskExecutor")
    public CompletableFuture<Void> sendLowStockAlertAsync(String productName, int currentQuantity) {
        log.warn("[ASYNC-NOTIFICATION] Low stock alert | product={} | quantity={} | thread={}",
                productName, currentQuantity, Thread.currentThread().getName());

        return CompletableFuture.completedFuture(null);
    }
}








