# Benchmark and Bottleneck Analysis

## Main Bottleneck

Repeated product retrieval from PostgreSQL.

## Optimization

Redis cache was introduced using Spring Cache.

## Cache Results

First request:
- PostgreSQL query executed

Second request:
- Redis cache hit

After stock update:
- Cache eviction executed
- Updated product reloaded

## Order Placement Observation

OrderService.placeOrder was identified by AOP as one of the slowest operations because it performs:

- Product locking
- Wallet validation
- Payment simulation
- Stock update
- Order creation
- Payment creation

## Stress Test Results

20 Concurrent Users:
- Passed

100 Concurrent Users:
- Passed

Overselling Attack:
- Passed

Final Stock:
- Never negative

## Conclusion

Redis reduced repeated database access.
Pessimistic locking prevented overselling.
Transactions preserved data consistency.
JMeter confirmed stable behavior under concurrent load.