package com.ecommerce.aspect;

import io.micrometer.core.instrument.*;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.*;
import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicInteger;

@Aspect
@Component
@RequiredArgsConstructor
@Slf4j
public class PerformanceMonitoringAspect {

    private final MeterRegistry meterRegistry;

    private final AtomicInteger activeServiceCalls = new AtomicInteger(0);

    @PostConstruct
    public void registerMetrics() {
        meterRegistry.gauge("ecommerce.active.service.calls", activeServiceCalls);
        log.info("[AOP] Performance metrics registered");
    }

    @Pointcut("execution(* com.ecommerce.service..*(..))")
    public void serviceLayer() {
    }

    @Pointcut("execution(* com.ecommerce.service.OrderService.placeOrder(..))")
    public void orderPlacement() {
    }

    @Around("serviceLayer()")
    public Object measureServiceMethod(ProceedingJoinPoint joinPoint) throws Throwable {

        String className = joinPoint.getTarget().getClass().getSimpleName();
        String methodName = joinPoint.getSignature().getName();

        activeServiceCalls.incrementAndGet();

        Timer.Sample sample = Timer.start(meterRegistry);
        long start = System.nanoTime();

        try {
            Object result = joinPoint.proceed();

            long durationMs = (System.nanoTime() - start) / 1_000_000;

            sample.stop(
                    Timer.builder("ecommerce.service.execution.time")
                            .tag("class", className)
                            .tag("method", methodName)
                            .tag("status", "success")
                            .register(meterRegistry)
            );

            if (durationMs > 500) {
                log.warn("[AOP] Slow method detected: {}.{} took {} ms",
                        className, methodName, durationMs);

                meterRegistry.counter(
                        "ecommerce.slow.service.methods",
                        "class", className,
                        "method", methodName
                ).increment();
            }

            return result;

        } catch (Exception ex) {

            sample.stop(
                    Timer.builder("ecommerce.service.execution.time")
                            .tag("class", className)
                            .tag("method", methodName)
                            .tag("status", "error")
                            .register(meterRegistry)
            );

            meterRegistry.counter(
                    "ecommerce.service.errors",
                    "class", className,
                    "method", methodName,
                    "exception", ex.getClass().getSimpleName()
            ).increment();

            log.error("[AOP] Service method failed: {}.{} | {}",
                    className, methodName, ex.getMessage());

            throw ex;

        } finally {
            activeServiceCalls.decrementAndGet();
        }
    }

    @Around("orderPlacement()")
    public Object monitorOrderPlacement(ProceedingJoinPoint joinPoint) throws Throwable {

        meterRegistry.counter("ecommerce.orders.attempts").increment();

        log.info("[AOP-ORDER] Order placement started | thread={}",
                Thread.currentThread().getName());

        try {
            Object result = joinPoint.proceed();

            meterRegistry.counter("ecommerce.orders.success").increment();

            log.info("[AOP-ORDER] Order placement succeeded");

            return result;

        } catch (Exception ex) {

            meterRegistry.counter(
                    "ecommerce.orders.failures",
                    "exception", ex.getClass().getSimpleName()
            ).increment();

            log.warn("[AOP-ORDER] Order placement failed: {}", ex.getMessage());

            throw ex;
        }
    }
}