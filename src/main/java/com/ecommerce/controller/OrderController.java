package com.ecommerce.controller;

import com.ecommerce.dto.ApiResponse;
import com.ecommerce.dto.OrderDTOs;
import com.ecommerce.entity.User;
import com.ecommerce.exception.BusinessException;
import com.ecommerce.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
@Slf4j
public class OrderController {

    private final OrderService orderService;

    @PostMapping
    public ResponseEntity<ApiResponse<OrderDTOs.OrderResponse>> placeOrder(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody OrderDTOs.CreateOrderRequest request
    ) {
        if (user == null) {
            throw new BusinessException("Authenticated user is required");
        }

        log.info("[ORDER-CTRL] New order request | user={} | items={}",
                user.getId(),
                request.getItems().size()
        );

        OrderDTOs.OrderResponse response =
                orderService.placeOrder(user.getId(), request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.ok(response.getMessage(), response));
    }

    @GetMapping("/my")
    public ResponseEntity<ApiResponse<?>> getMyOrders(
            @AuthenticationPrincipal User user
    ) {
        if (user == null) {
            throw new BusinessException("Authenticated user is required");
        }

        return ResponseEntity.ok(
                ApiResponse.ok(
                        "Orders fetched successfully",
                        orderService.getUserOrders(user.getId())
                )
        );
    }
}