package com.ecommerce.controller;

import com.ecommerce.batch.BatchScheduler;
import com.ecommerce.config.LoadBalancerConfig;
import com.ecommerce.dto.ApiResponse;
import com.ecommerce.lock.RedisDistributedLockService;
import com.ecommerce.repository.UserRepository;
import com.ecommerce.service.AdminStatsService;
import lombok.Builder;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private static final String DAILY_SALES_BATCH_LOCK_KEY = "lock:daily-sales-batch";
    private static final Duration DAILY_SALES_BATCH_LOCK_TTL = Duration.ofSeconds(60);

    private final UserRepository userRepository;
    private final BatchScheduler batchScheduler;
    private final LoadBalancerConfig.WeightedRoundRobinLoadBalancer loadBalancer;
    private final RedisDistributedLockService distributedLockService;
    private final AdminStatsService adminStatsService;

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
    public ResponseEntity<ApiResponse<AdminStatsService.AdminStatsSnapshot>> stats() {
        return ResponseEntity.ok(
                ApiResponse.ok("Admin stats fetched successfully", adminStatsService.getLast24HoursStats())
        );
    }

    @PostMapping("/batch/run")
    public ResponseEntity<ApiResponse<String>> runBatch() {

        var lockHandle = distributedLockService.tryAcquire(
                DAILY_SALES_BATCH_LOCK_KEY,
                DAILY_SALES_BATCH_LOCK_TTL
        );

        if (lockHandle.isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.LOCKED)
                    .body(ApiResponse.error(
                            "Batch is already running under a Redis distributed lock",
                            DAILY_SALES_BATCH_LOCK_KEY
                    ));
        }

        try {
            String result = batchScheduler.runManually();

            return ResponseEntity.ok(
                    ApiResponse.ok("Batch executed successfully", result)
            );
        } finally {
            distributedLockService.release(lockHandle.get());
        }
    }

    @GetMapping("/batch/lock-status")
    public ResponseEntity<ApiResponse<Map<String, Object>>> batchLockStatus() {
        Map<String, Object> result = Map.of(
                "lockKey", DAILY_SALES_BATCH_LOCK_KEY,
                "locked", distributedLockService.isLocked(DAILY_SALES_BATCH_LOCK_KEY),
                "ttlSeconds", distributedLockService.ttlSeconds(DAILY_SALES_BATCH_LOCK_KEY),
                "timestamp", LocalDateTime.now().toString()
        );

        return ResponseEntity.ok(
                ApiResponse.ok("Batch lock status fetched successfully", result)
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