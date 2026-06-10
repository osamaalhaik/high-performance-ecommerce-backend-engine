package com.ecommerce.entity;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class PaymentTest {

    @Test
    void successfulPaymentCanStoreTransactionReference() {
        Payment payment = Payment.builder()
                .amount(1200.0)
                .status(Payment.PaymentStatus.SUCCESS)
                .transactionRef("TXN-TEST123")
                .processedAt(LocalDateTime.now())
                .build();

        assertEquals(1200.0, payment.getAmount());
        assertEquals(Payment.PaymentStatus.SUCCESS, payment.getStatus());
        assertEquals("TXN-TEST123", payment.getTransactionRef());
        assertNotNull(payment.getProcessedAt());
    }
}
