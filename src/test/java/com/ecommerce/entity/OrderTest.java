package com.ecommerce.entity;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class OrderTest {

    @Test
    void confirmedOrderStoresItemsAndTotalAmount() {
        OrderItem item = OrderItem.builder()
                .quantity(2)
                .unitPrice(500.0)
                .build();

        Order order = Order.builder()
                .totalAmount(1000.0)
                .status(Order.OrderStatus.CONFIRMED)
                .items(List.of(item))
                .build();

        assertEquals(1000.0, order.getTotalAmount());
        assertEquals(Order.OrderStatus.CONFIRMED, order.getStatus());
        assertEquals(1, order.getItems().size());
    }
}
