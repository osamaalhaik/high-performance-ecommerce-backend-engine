package com.ecommerce.controller;

import com.ecommerce.dto.ApiResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api/instance")
public class InstanceController {

    @Value("${app.instance-name:${spring.application.name}}")
    private String instanceName;

    @Value("${server.port}")
    private String serverPort;

    @GetMapping
    public ResponseEntity<ApiResponse<Map<String, Object>>> currentInstance() {
        Map<String, Object> result = Map.of(
                "instanceName", instanceName,
                "serverPort", serverPort,
                "thread", Thread.currentThread().getName(),
                "timestamp", LocalDateTime.now().toString()
        );

        return ResponseEntity.ok(
                ApiResponse.ok("Instance information fetched successfully", result)
        );
    }
}