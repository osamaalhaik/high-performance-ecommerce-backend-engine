package com.ecommerce.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
@Slf4j
public class NotificationService {

    public void sendOrderConfirmation(String email, String orderId) {
        log.info("[NOTIFICATION] Sending confirmation email | email={} | order={} | thread={}",
                email, orderId, Thread.currentThread().getName());

        try {
            Thread.sleep(500);
            log.info("[NOTIFICATION] Confirmation email sent | email={} | order={}", email, orderId);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Order confirmation notification interrupted", ex);
        }
    }

    public void sendLowStockAlert(String productName, int currentQuantity) {
        log.warn("[NOTIFICATION] Low stock alert | product={} | quantity={} | thread={}",
                productName, currentQuantity, Thread.currentThread().getName());
    }

    @Async("taskExecutor")
    public CompletableFuture<Void> sendOrderConfirmationAsync(String email, String orderId) {
        sendOrderConfirmation(email, orderId);
        return CompletableFuture.completedFuture(null);
    }

    @Async("taskExecutor")
    public CompletableFuture<Void> sendLowStockAlertAsync(String productName, int currentQuantity) {
        sendLowStockAlert(productName, currentQuantity);
        return CompletableFuture.completedFuture(null);
    }
}