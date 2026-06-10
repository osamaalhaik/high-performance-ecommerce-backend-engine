package com.ecommerce.entity;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ProductTest {

    @Test
    void productStoresStockAndVersionFields() {
        Product product = Product.builder()
                .name("Test Product")
                .description("Concurrency test product")
                .price(100.0)
                .stockQuantity(10)
                .version(1L)
                .build();

        assertEquals("Test Product", product.getName());
        assertEquals(100.0, product.getPrice());
        assertEquals(10, product.getStockQuantity());
        assertEquals(1L, product.getVersion());
    }

    @Test
    void stockCanBeReducedWithoutGoingNegativeWhenCheckedBeforeUpdate() {
        Product product = Product.builder()
                .name("Inventory Product")
                .price(50.0)
                .stockQuantity(5)
                .version(1L)
                .build();

        int requestedQuantity = 3;

        assertTrue(product.getStockQuantity() >= requestedQuantity);

        product.setStockQuantity(product.getStockQuantity() - requestedQuantity);

        assertEquals(2, product.getStockQuantity());
        assertTrue(product.getStockQuantity() >= 0);
    }
}
