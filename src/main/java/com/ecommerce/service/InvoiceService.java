package com.ecommerce.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
@Slf4j
public class InvoiceService {

    @Async("taskExecutor")
    public CompletableFuture<String> generateInvoiceAsync(String orderId, String email, double amount) {
        log.info("[ASYNC-INVOICE] Generating invoice | order={} | email={} | thread={}",
                orderId, email, Thread.currentThread().getName());

        try {
            Thread.sleep(800);

            String invoiceRef = "INV-" + orderId.substring(0, 8).toUpperCase();

            log.info("[ASYNC-INVOICE] Invoice generated | ref={} | amount={}", invoiceRef, amount);

            return CompletableFuture.completedFuture(invoiceRef);

        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            return CompletableFuture.failedFuture(ex);
        }
    }
}