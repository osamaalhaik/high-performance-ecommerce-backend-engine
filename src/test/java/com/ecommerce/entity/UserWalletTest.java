package com.ecommerce.entity;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class UserWalletTest {

    @Test
    void userWalletBalanceCanBeDeductedAfterSuccessfulPayment() {
        User user = User.builder()
                .email("wallet-unit@test.com")
                .passwordHash("encoded-password")
                .fullName("Wallet Unit Test")
                .walletBalance(10000.0)
                .role(User.Role.CUSTOMER)
                .build();

        double orderTotal = 1200.0;

        assertTrue(user.getWalletBalance() >= orderTotal);

        user.setWalletBalance(user.getWalletBalance() - orderTotal);

        assertEquals(8800.0, user.getWalletBalance());
    }

    @Test
    void userWalletBalanceRejectsInsufficientPaymentScenario() {
        User user = User.builder()
                .email("poor-wallet@test.com")
                .passwordHash("encoded-password")
                .fullName("Poor Wallet Test")
                .walletBalance(500.0)
                .role(User.Role.CUSTOMER)
                .build();

        double orderTotal = 1200.0;

        assertFalse(user.getWalletBalance() >= orderTotal);
    }
}
