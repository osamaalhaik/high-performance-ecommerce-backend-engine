package com.ecommerce.lock;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Collections;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class RedisDistributedLockService {

    private final StringRedisTemplate redisTemplate;

    public Optional<LockHandle> tryAcquire(String key, Duration ttl) {
        String token = UUID.randomUUID().toString();
        Boolean acquired = redisTemplate.opsForValue().setIfAbsent(key, token, ttl);

        if (Boolean.TRUE.equals(acquired)) {
            log.info("[DISTRIBUTED-LOCK] acquired | key={} | ttlSeconds={}", key, ttl.toSeconds());
            return Optional.of(new LockHandle(key, token));
        }

        log.warn("[DISTRIBUTED-LOCK] rejected | key={} | reason=already-held", key);
        return Optional.empty();
    }

    public boolean release(LockHandle handle) {
        String scriptText = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";
        DefaultRedisScript<Long> script = new DefaultRedisScript<>(scriptText, Long.class);

        Long result = redisTemplate.execute(
                script,
                Collections.singletonList(handle.key()),
                handle.token()
        );

        boolean released = result != null && result == 1L;

        if (released) {
            log.info("[DISTRIBUTED-LOCK] released | key={}", handle.key());
        } else {
            log.warn("[DISTRIBUTED-LOCK] release-skipped | key={} | reason=token-mismatch-or-expired", handle.key());
        }

        return released;
    }

    public boolean isLocked(String key) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(key));
    }

    public Long ttlSeconds(String key) {
        return redisTemplate.getExpire(key);
    }

    public record LockHandle(String key, String token) {
    }
}