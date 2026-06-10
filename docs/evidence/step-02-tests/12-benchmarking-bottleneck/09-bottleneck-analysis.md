# Benchmarking and Bottleneck Analysis

## Numeric Benchmark Summary

- Product cache miss: 42 ms
- Product cache hit average over 20 reads: 36.5 ms
- Product cache improvement: 13.1 %

- Admin stats cache miss: 32 ms
- Admin stats cache hit average over 20 reads: 26.85 ms
- Admin stats cache improvement: 16.09 %

- Order creation average over 10 orders: 1264.4 ms
- Order creation min: 1252 ms
- Order creation max: 1277 ms

## Identified Bottleneck

The main bottleneck is: Transactional order creation path.

Reason: Order creation is slower than cached reads because it performs authenticated request validation, wallet balance verification, pessimistic database locks for user wallet and product stock, stock update, order persistence, payment persistence, cache eviction, and Redis queue enqueue operations.

## Conclusion

Caching reduces repeated read pressure on the database for product reads and admin statistics. The order creation path remains intentionally heavier because it protects shared data integrity through wallet verification, stock locking, transactional persistence, payment handling, cache eviction, and asynchronous queue submission. This bottleneck is acceptable and justified because it protects correctness under concurrency.
