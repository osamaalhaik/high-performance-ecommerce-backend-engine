# Benchmark and Bottleneck Analysis

## Benchmark Scope

The benchmark evidence focuses on product reads, admin statistics, order creation, JMeter 100 users stress testing, and Prometheus service execution metrics.

## Main Bottleneck

The main bottleneck is the order creation path.

Reason:

- It runs inside a database transaction.
- It validates stock.
- It validates wallet balance.
- It persists order data.
- It persists payment data.
- It updates product stock.
- It triggers post-order processing.

## Evidence

| Evidence | Path |
|---|---|
| JMeter summary | jmeter/screenshots/12-summary-zero-errors.png |
| AOP service execution metrics | monitoring/screenshots/01-actuator-prometheus-aop-service-metrics.png |
| Order counters | monitoring/screenshots/02-actuator-prometheus-orders-attempts-metrics.png |
| Order success metrics | monitoring/screenshots/03-actuator-prometheus-orders-success-metrics.png |
| Order failure metrics | monitoring/screenshots/04-actuator-prometheus-orders-failures-metrics.png |

## Final Interpretation

The system prioritizes correctness over raw speed in the order transaction path. This is appropriate for an e-commerce backend because overselling and wallet inconsistency are more serious than slower transaction latency.
