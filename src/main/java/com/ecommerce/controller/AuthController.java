package com.ecommerce.controller;

import com.ecommerce.dto.ApiResponse;
import com.ecommerce.dto.AuthDTOs;
import com.ecommerce.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthDTOs.AuthResponse>> register(
            @Valid @RequestBody AuthDTOs.RegisterRequest request
    ) {

        log.info(
                "[AUTH-CTRL] Register request received for: {}",
                request.getEmail()
        );

        AuthDTOs.AuthResponse response =
                authService.register(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(
                        ApiResponse.ok(
                                "User registered successfully",
                                response
                        )
                );
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthDTOs.AuthResponse>> login(
            @Valid @RequestBody AuthDTOs.LoginRequest request
    ) {

        log.info(
                "[AUTH-CTRL] Login request received for: {}",
                request.getEmail()
        );

        AuthDTOs.AuthResponse response =
                authService.login(request);

        return ResponseEntity.ok(
                ApiResponse.ok(
                        "Login successful",
                        response
                )
        );
    }
}