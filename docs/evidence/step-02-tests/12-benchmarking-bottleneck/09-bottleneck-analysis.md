# Benchmarking and Bottleneck Analysis

## Numeric Benchmark Summary

- Product cache miss: 50 ms
- Product cache hit average over 20 reads: 34.9 ms
- Product cache improvement: 30.2 %

- Admin stats cache miss: 43 ms
- Admin stats cache hit average over 20 reads: 32.7 ms
- Admin stats cache improvement: 23.95 %

- Order creation average over 10 orders: 1279.9 ms
- Order creation min: 1252 ms
- Order creation max: 1329 ms

## Identified Bottleneck

The main bottleneck is: Transactional order creation path.

Reason: Order creation is slower than cached reads because it performs authenticated request validation, wallet balance verification, pessimistic database locks for user wallet and product stock, stock update, order persistence, payment persistence, cache eviction, and Redis queue enqueue operations.

## Conclusion

Caching reduces repeated read pressure on the database for product reads and admin statistics. The order creation path remains intentionally heavier because it protects shared data integrity through wallet verification, stock locking, transactional persistence, payment handling, cache eviction, and asynchronous queue submission. This bottleneck is acceptable and justified because it protects correctness under concurrency.
