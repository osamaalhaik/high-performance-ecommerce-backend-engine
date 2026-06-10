package com.ecommerce.service;

import com.ecommerce.config.LoadBalancerConfig;
import com.ecommerce.repository.OrderRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class AdminStatsService {

    private static final String ADMIN_STATS_CACHE_KEY = "ecommerce:cache:admin-stats:last24h";
    private static final Duration ADMIN_STATS_TTL = Duration.ofSeconds(30);

    private final OrderRepository orderRepository;
    private final LoadBalancerConfig.WeightedRoundRobinLoadBalancer loadBalancer;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public AdminStatsSnapshot getLast24HoursStats() {
        String cached = redisTemplate.opsForValue().get(ADMIN_STATS_CACHE_KEY);

        if (cached != null) {
            try {
                log.info("[CACHE] Admin stats cache hit | key={}", ADMIN_STATS_CACHE_KEY);
                return objectMapper.readValue(cached, AdminStatsSnapshot.class);
            } catch (Exception ex) {
                log.warn("[CACHE] Admin stats cache read failed | key={} | error={}", ADMIN_STATS_CACHE_KEY, ex.getMessage());
                redisTemplate.delete(ADMIN_STATS_CACHE_KEY);
            }
        }

        LocalDateTime since24h = LocalDateTime.now().minusHours(24);

        AdminStatsSnapshot snapshot = new AdminStatsSnapshot(
                orderRepository.countOrdersSince(since24h),
                orderRepository.sumRevenueSince(since24h),
                Thread.activeCount(),
                loadBalancer.stats(),
                LocalDateTime.now().toString()
        );

        try {
            redisTemplate.opsForValue().set(
                    ADMIN_STATS_CACHE_KEY,
                    objectMapper.writeValueAsString(snapshot),
                    ADMIN_STATS_TTL
            );
            log.info("[CACHE] Admin stats cache miss | key={} | ttlSeconds={}", ADMIN_STATS_CACHE_KEY, ADMIN_STATS_TTL.toSeconds());
        } catch (Exception ex) {
            log.warn("[CACHE] Admin stats cache write failed | key={} | error={}", ADMIN_STATS_CACHE_KEY, ex.getMessage());
        }

        return snapshot;
    }

    public record AdminStatsSnapshot(
            Long ordersLast24h,
            Double revenueLast24h,
            Integer activeThreads,
            String loadBalancerStats,
            String timestamp
    ) {
    }
}