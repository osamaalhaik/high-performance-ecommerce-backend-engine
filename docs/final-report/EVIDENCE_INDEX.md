# Evidence Index

Project: High-Performance E-Commerce Backend Engine

This file lists the final verification evidence produced for the project.

## 01 - Build Verification

Path:

docs/evidence/step-02-tests/01-build

Purpose:

Proves that the project compiles successfully and that the automated Java test suite passes through Maven.

Key files:

- 01-maven-clean-test-output.txt
- 02-maven-clean-test-summary.json

## 02 - Runtime Smoke Test

Path:

docs/evidence/step-02-tests/02-runtime-smoke

Purpose:

Proves that the running backend can execute the main runtime flow: health check, product creation, cached product read, order creation, user orders, admin statistics, batch lock status, and instance information.

Key files:

- 01-health.json
- 05-order-created.json
- 11-runtime-smoke-summary.json

## 03 - Concurrent Access and Data Integrity

Path:

docs/evidence/step-02-tests/03-concurrent-access

Purpose:

Proves that concurrent users cannot oversell product stock and that stock integrity remains valid under parallel order attempts.

Key files:

- 01-concurrent-order-results.json
- 02-final-product-state.json
- 03-concurrent-order-summary.json

## 04 - Redis Distributed Cache

Path:

docs/evidence/step-02-tests/04-redis-cache

Purpose:

Proves that product reads and admin statistics use Redis caching and that cache keys are created with valid TTL values.

Key files:

- 03-product-second-read.json
- 05-admin-stats-second-read.json
- 06-redis-cache-summary.json

## 05 - Redis Queue and Asynchronous Processing

Path:

docs/evidence/step-02-tests/05-redis-queue

Purpose:

Proves that invoice and notification jobs are submitted to Redis Queue and processed asynchronously outside the main request path.

Key files:

- 01-order-results.json
- 04-redis-queue-summary.json

## 06 - Redis Distributed Lock

Path:

docs/evidence/step-02-tests/06-distributed-lock

Purpose:

Proves that Redis distributed locking protects batch execution from duplicate concurrent execution.

Key files:

- 03-batch-run-while-locked.json
- 05-batch-run-after-unlock.json
- 07-distributed-lock-summary.json

## 07 - Transaction Integrity and ACID Rollback

Path:

docs/evidence/step-02-tests/07-transaction-integrity

Purpose:

Proves that a successful order updates stock and creates an order, while a failed order caused by insufficient wallet balance rolls back without changing stock or creating an order.

Key files:

- 02-success-order-response.json
- 08-failure-product-after-failed-order.json
- 10-transaction-integrity-summary.json

## 08 - Batch Processing

Path:

docs/evidence/step-02-tests/08-batch-processing

Purpose:

Proves that a batch job can process real order data successfully.

Key files:

- 02-seed-order-results.json
- 03-batch-run-response.json
- 05-batch-processing-summary.json

## 09 - Resource Management and Capacity Control

Path:

docs/evidence/step-02-tests/09-resource-management

Purpose:

Proves that the application exposes health and metrics endpoints, keeps DB and Redis healthy, uses async thread pool configuration, and remains stable under concurrent workload.

Key files:

- 03-selected-metrics-before.json
- 05-selected-metrics-during-load.json
- 12-resource-management-summary.json

## 10 - Load Balancing and Scaling Strategy

Path:

docs/evidence/step-02-tests/10-load-balancing

Purpose:

Proves the existence of an Nginx load balancing configuration and internal weighted round-robin server selection logic.

Key files:

- 03-load-balancer-distribution.json
- 04-nginx-config-source.txt
- 06-load-balancing-summary.json

## 11 - Stress Test with 100 Concurrent Users

Path:

docs/evidence/step-02-tests/11-stress-100-users

Purpose:

Proves that 100 concurrent users completed full user flows successfully with zero server errors, zero timeout jobs, and correct stock integrity.

Key files:

- 04-user-flow-results.json
- 06-final-products-state.json
- 07-stress-100-users-summary.json

## 12 - Benchmarking and Bottleneck Analysis

Path:

docs/evidence/step-02-tests/12-benchmarking-bottleneck

Purpose:

Proves measurable performance comparison before and after cache hits, and identifies the transactional order creation path as the main bottleneck.

Key files:

- 08-benchmark-summary.json
- 09-bottleneck-analysis.md

<!-- AUTO-JMETER-STRESS-START -->
## JMeter 100 Users Stress Test and Bottleneck Analysis

A 100-user JMeter stress test was executed on the backend using a scenario composed of Register Customer, Read Product From Catalog, and Place Order. The test produced 300 total samples.

Before capacity tuning, the system preserved stock integrity but exposed a bottleneck in the Place Order path. The first run produced 17 failed samples out of 300, with an error rate of 5.67%. Stock integrity remained correct because the stock moved from 1000 to 916, matching 84 successful order requests.

After capacity tuning, Hikari maximum-pool-size was increased from 20 to 50, Hikari connection-timeout from 30000ms to 180000ms, and async queue-capacity from 100 to 300. The final run completed 300 successful samples out of 300, with 0% error rate. The Place Order request completed 100 successful orders and the stock moved from 1000 to 900, exactly matching the expected stock value after successful orders.

This evidence proves stress testing, bottleneck analysis, resource capacity management, ACID transaction integrity, and shared stock protection under concurrent access.

Detailed evidence is available in:

- docs/final-report/JMETER_100_USERS_STRESS_TEST_AND_BOTTLENECK_ANALYSIS.md
- docs/evidence/step-04-jmeter-100-users-final/
- docs/evidence/step-05-jmeter-100-users-capacity-tuned/
- jmeter/results/100-users-capacity-tuned-20260611-142546/html-report/index.html
<!-- AUTO-JMETER-STRESS-END -->
