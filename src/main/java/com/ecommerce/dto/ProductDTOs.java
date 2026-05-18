package com.ecommerce.dto;

import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDateTime;

public class ProductDTOs {

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateProductRequest {

        @NotBlank(message = "Product name is required")
        private String name;

        private String description;

        @NotNull(message = "Price is required")
        @Positive(message = "Price must be positive")
        private Double price;

        @NotNull(message = "Stock quantity is required")
        @Min(value = 0, message = "Stock quantity cannot be negative")
        private Integer stockQuantity;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UpdateStockRequest {

        @NotNull(message = "Quantity is required")
        @Min(value = 0, message = "Quantity cannot be negative")
        private Integer quantity;

        @NotNull(message = "Version is required")
        @Min(value = 0, message = "Version cannot be negative")
        private Long version;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ProductResponse {

        private String id;
        private String name;
        private String description;
        private Double price;
        private Integer stockQuantity;
        private Long version;
        private LocalDateTime createdAt;
    }
}