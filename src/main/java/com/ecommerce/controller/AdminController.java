package com.ecommerce.controller;

import com.ecommerce.batch.BatchScheduler;
import com.ecommerce.config.LoadBalancerConfig;
import com.ecommerce.dto.ApiResponse;
import com.ecommerce.entity.User;
import com.ecommerce.repository.OrderRepository;
import com.ecommerce.repository.UserRepository;
import lombok.Builder;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final OrderRepository orderRepository;
    private final UserRepository userRepository;
    private final BatchScheduler batchScheduler;
    private final LoadBalancerConfig.WeightedRoundRobinLoadBalancer loadBalancer;

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<List<AdminUserResponse>>> getUsers() {

        List<AdminUserResponse> users = userRepository.findAll()
                .stream()
                .map(user -> AdminUserResponse.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .fullName(user.getFullName())
                        .role(user.getRole().name())
                        .createdAt(user.getCreatedAt())
                        .build())
                .toList();

        return ResponseEntity.ok(
                ApiResponse.ok("Users fetched successfully", users)
        );
    }

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<Map<String, Object>>> stats() {

        LocalDateTime since24h = LocalDateTime.now().minusHours(24);

        Map<String, Object> result = Map.of(
                "orders_last_24h", orderRepository.countOrdersSince(since24h),
                "revenue_last_24h", orderRepository.sumRevenueSince(since24h),
                "active_threads", Thread.activeCount(),
                "load_balancer_stats", loadBalancer.stats(),
                "timestamp", LocalDateTime.now().toString()
        );

        return ResponseEntity.ok(
                ApiResponse.ok("Admin stats fetched successfully", result)
        );
    }

    @PostMapping("/batch/run")
    public ResponseEntity<ApiResponse<String>> runBatch() {

        String result = batchScheduler.runManually();

        return ResponseEntity.ok(
                ApiResponse.ok("Batch executed successfully", result)
        );
    }

    @GetMapping("/lb/next")
    public ResponseEntity<ApiResponse<String>> nextServer() {

        return ResponseEntity.ok(
                ApiResponse.ok("Next server selected", loadBalancer.nextServer())
        );
    }

    @Builder
    public record AdminUserResponse(
            String id,
            String email,
            String fullName,
            String role,
            LocalDateTime createdAt
    ) {
    }
}
