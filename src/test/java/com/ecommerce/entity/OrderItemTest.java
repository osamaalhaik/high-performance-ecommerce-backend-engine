package com.ecommerce.entity;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class OrderItemTest {

    @Test
    void subtotalIsCalculatedFromUnitPriceAndQuantity() {
        OrderItem item = OrderItem.builder()
                .unitPrice(1200.0)
                .quantity(3)
                .build();

        assertEquals(3600.0, item.getSubtotal());
    }
}
