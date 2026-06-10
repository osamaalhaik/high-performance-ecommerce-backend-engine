package com.ecommerce.dto;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class OrderDTOsTest {

    @Test
    void createOrderRequestCanHoldMultipleItems() {
        OrderDTOs.OrderItemRequest item1 =
                new OrderDTOs.OrderItemRequest("product-1", 2);

        OrderDTOs.OrderItemRequest item2 =
                new OrderDTOs.OrderItemRequest("product-2", 3);

        OrderDTOs.CreateOrderRequest request =
                new OrderDTOs.CreateOrderRequest(List.of(item1, item2));

        assertEquals(2, request.getItems().size());
        assertEquals("product-1", request.getItems().get(0).getProductId());
        assertEquals(2, request.getItems().get(0).getQuantity());
        assertEquals("product-2", request.getItems().get(1).getProductId());
        assertEquals(3, request.getItems().get(1).getQuantity());
    }
}
