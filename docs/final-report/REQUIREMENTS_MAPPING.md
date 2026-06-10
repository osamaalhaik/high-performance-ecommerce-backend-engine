# Requirements Mapping

Project: High-Performance E-Commerce Backend Engine

This file maps the official project requirements to the implemented backend mechanisms and evidence files.

## Requirement 1 - Concurrent Access and Data Integrity

Implemented by:

- Pessimistic product stock locking.
- Transactional order creation.
- Concurrent stock integrity verification script.

Evidence:

- docs/evidence/step-02-tests/03-concurrent-access/03-concurrent-order-summary.json
- docs/evidence/step-02-tests/11-stress-100-users/07-stress-100-users-summary.json

## Requirement 2 - Resource Management and Capacity Control

Implemented by:

- Spring Boot Actuator health and metrics.
- HikariCP monitoring.
- JVM thread metrics.
- Async thread pool configuration.
- Controlled concurrent workload test.

Evidence:

- docs/evidence/step-02-tests/09-resource-management/12-resource-management-summary.json
- docs/evidence/step-02-tests/09-resource-management/10-async-config-source.txt
- docs/evidence/step-02-tests/09-resource-management/11-application-config-source.txt

## Requirement 3 - Asynchronous Queues

Implemented by:

- Redis-backed async job queue.
- Invoice jobs.
- Order confirmation jobs.
- Low-stock notification jobs.
- Scheduled queue worker.

Evidence:

- docs/evidence/step-02-tests/05-redis-queue/04-redis-queue-summary.json

## Requirement 4 - Batch Processing

Implemented by:

- Spring Batch daily sales report job.
- Manual protected batch execution endpoint.
- Redis lock protection around batch execution.

Evidence:

- docs/evidence/step-02-tests/08-batch-processing/05-batch-processing-summary.json
- docs/evidence/step-02-tests/06-distributed-lock/07-distributed-lock-summary.json

## Requirement 5 - Load Distribution and Scaling Strategy

Implemented by:

- Nginx upstream configuration.
- Weighted backend instances.
- Internal weighted round-robin strategy verification endpoint.

Evidence:

- docs/evidence/step-02-tests/10-load-balancing/04-nginx-config-source.txt
- docs/evidence/step-02-tests/10-load-balancing/06-load-balancing-summary.json

## Requirement 6 - Distributed Caching

Implemented by:

- Redis product cache.
- Redis admin statistics cache.
- Cache TTL validation.
- Repeated read benchmark.

Evidence:

- docs/evidence/step-02-tests/04-redis-cache/06-redis-cache-summary.json
- docs/evidence/step-02-tests/12-benchmarking-bottleneck/08-benchmark-summary.json

## Requirement 7 - Concurrency Control, Locks, and Transactions

Implemented by:

- Pessimistic database locks for product stock.
- Pessimistic database lock for wallet balance.
- Redis distributed lock for batch processing.
- Transactional order service.

Evidence:

- docs/evidence/step-02-tests/03-concurrent-access/03-concurrent-order-summary.json
- docs/evidence/step-02-tests/06-distributed-lock/07-distributed-lock-summary.json
- docs/evidence/step-02-tests/07-transaction-integrity/10-transaction-integrity-summary.json

## Requirement 8 - Transaction Integrity and ACID

Implemented by:

- Single transactional order creation boundary.
- Wallet verification before persistence.
- Stock update inside transaction.
- Order and payment persistence inside transaction.
- Rollback on insufficient wallet balance.

Evidence:

- docs/evidence/step-02-tests/07-transaction-integrity/10-transaction-integrity-summary.json

## Requirement 9 - Stress Testing

Implemented by:

- 100 concurrent user stress script.
- Full user flow per user.
- Product browsing, product details, and order creation.
- Final stock integrity verification.

Evidence:

- docs/evidence/step-02-tests/11-stress-100-users/07-stress-100-users-summary.json

## Requirement 10 - Benchmarking and Bottleneck Analysis

Implemented by:

- Product cache miss versus cache hit benchmark.
- Admin statistics cache miss versus cache hit benchmark.
- Order creation timing benchmark.
- Bottleneck identification.

Evidence:

- docs/evidence/step-02-tests/12-benchmarking-bottleneck/08-benchmark-summary.json
- docs/evidence/step-02-tests/12-benchmarking-bottleneck/09-bottleneck-analysis.md