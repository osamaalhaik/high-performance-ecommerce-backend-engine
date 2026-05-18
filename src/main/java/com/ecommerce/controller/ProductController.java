package com.ecommerce.controller;

import com.ecommerce.dto.ApiResponse;
import com.ecommerce.dto.ProductDTOs;
import com.ecommerce.service.ProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<ProductDTOs.ProductResponse>> getProduct(
            @PathVariable String id
    ) {
        return ResponseEntity.ok(
                ApiResponse.ok(
                        productService.getProductById(id)
                )
        );
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<ProductDTOs.ProductResponse>>> getAllProducts(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ResponseEntity.ok(
                ApiResponse.ok(
                        productService.getAllProducts(page, size)
                )
        );
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<ProductDTOs.ProductResponse>> createProduct(
            @Valid @RequestBody ProductDTOs.CreateProductRequest request
    ) {
        ProductDTOs.ProductResponse response = productService.createProduct(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Product created", response));
    }

    @PatchMapping("/{id}/stock")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<ProductDTOs.ProductResponse>> updateStock(
            @PathVariable String id,
            @Valid @RequestBody ProductDTOs.UpdateStockRequest request
    ) {
        ProductDTOs.ProductResponse response =
                productService.updateStock(id, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Stock updated", response)
        );
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteProduct(
            @PathVariable String id
    ) {
        productService.deleteProduct(id);

        return ResponseEntity.ok(
                ApiResponse.ok("Product deleted", null)
        );
    }
}