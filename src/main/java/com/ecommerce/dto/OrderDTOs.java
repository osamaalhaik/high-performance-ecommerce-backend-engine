package com.ecommerce.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.List;

public class OrderDTOs {

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateOrderRequest {

        @Valid
        @NotEmpty(message = "Order must contain at least one item")
        private List<OrderItemRequest> items;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OrderItemRequest {

        @NotBlank(message = "Product id is required")
        private String productId;

        @NotNull(message = "Quantity is required")
        @Min(value = 1, message = "Quantity must be at least 1")
        private Integer quantity;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class OrderItemResponse {

        private String productId;
        private String productName;
        private Integer quantity;
        private Double unitPrice;
        private Double subtotal;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class OrderResponse {

        private String orderId;
        private String status;
        private Double totalAmount;
        private List<OrderItemResponse> items;
        private LocalDateTime createdAt;
        private String message;
    }
}