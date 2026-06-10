# High-Performance E-Commerce Backend Engine

## Project Overview

High-Performance E-Commerce Backend Engine is a Spring Boot backend project built for a Parallel Programming course.

The project focuses on backend non-functional requirements under high concurrency: data integrity, transaction safety, resource management, asynchronous processing, batch processing, distributed caching, locking, stress testing, and benchmarking.

The project does not focus on UI pages. It proves backend correctness and performance under concurrent load.

## Main Technologies

- Java 17
- Spring Boot 3
- Spring Security with JWT
- Spring Data JPA
- PostgreSQL
- Redis
- Spring Batch
- Spring Boot Actuator
- Maven
- Nginx load balancing configuration
- PowerShell automated verification scripts

## Verified Requirements

| Requirement | Status | Evidence |
|---|---:|---|
| Concurrent Access and Data Integrity | Passed | docs/evidence/step-02-tests/03-concurrent-access |
| Resource Management and Capacity Control | Passed | docs/evidence/step-02-tests/09-resource-management |
| Asynchronous Queues | Passed | docs/evidence/step-02-tests/05-redis-queue |
| Batch Processing | Passed | docs/evidence/step-02-tests/08-batch-processing |
| Load Balancing and Scaling Strategy | Passed | docs/evidence/step-02-tests/10-load-balancing |
| Distributed Caching | Passed | docs/evidence/step-02-tests/04-redis-cache |
| Concurrency Control and Locks | Passed | docs/evidence/step-02-tests/06-distributed-lock |
| Transaction Integrity and ACID | Passed | docs/evidence/step-02-tests/07-transaction-integrity |
| Stress Testing with 100 Users | Passed | docs/evidence/step-02-tests/11-stress-100-users |
| Benchmarking and Bottleneck Analysis | Passed | docs/evidence/step-02-tests/12-benchmarking-bottleneck |

## Key Final Results

- Maven tests: 13 passed, 0 failures, 0 errors.
- 100 concurrent users: 100 successful flows, 0 failed flows, 0 server errors, 0 timeouts.
- Stock integrity under stress: true.
- Redis cache verified for products and admin statistics.
- Redis queue verified for asynchronous invoice and notification processing.
- Redis distributed lock verified for batch protection.
- ACID rollback verified for insufficient wallet balance.
- Main bottleneck identified: Transactional order creation path.

## Final Documentation

- docs/final-report/EVIDENCE_INDEX.md
- docs/final-report/REQUIREMENTS_MAPPING.md
- docs/final-report/DEFENSE_NOTES.md
- docs/final-report/DELIVERY_CHECKLIST.md

## Evidence

All final evidence is stored in docs/evidence/step-02-tests.

## Verification Scripts

All verification scripts are stored in tests/powershell.

## Build Verification

Run: .\mvnw clean test

Expected result: Tests run: 13, Failures: 0, Errors: 0, Skipped: 0 and BUILD SUCCESS.

## Final Submission Tag

v1.0-final-submission-complete
