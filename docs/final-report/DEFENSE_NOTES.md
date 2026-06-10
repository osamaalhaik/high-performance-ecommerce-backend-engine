# Defense Notes

Project: High-Performance E-Commerce Backend Engine

## Project Summary

The project is a backend engine for an e-commerce system designed to handle high concurrency and protect shared data integrity. The focus is not on building a user interface, but on implementing and proving non-functional requirements such as concurrency safety, transactional correctness, caching, asynchronous processing, batch processing, resource monitoring, stress testing, and benchmarking.

## Main Technical Stack

- Java 17
- Spring Boot 3
- Spring Security with JWT
- Spring Data JPA
- PostgreSQL
- Redis
- Spring Batch
- Spring Actuator
- Maven
- PowerShell test automation
- Nginx configuration for load balancing strategy

## Core User Flow

1. Admin creates products.
2. Customer registers and receives JWT token.
3. Customer browses products.
4. Customer creates an order.
5. System verifies wallet balance.
6. System locks user wallet and product stock.
7. System updates stock.
8. System creates order and payment records.
9. System evicts affected cache entries.
10. System enqueues invoice and notification jobs into Redis Queue.

## Why Pessimistic Locking Was Used

Pessimistic locking was used for stock and wallet operations because these are critical shared resources. When many users try to buy the same product at the same time, the system must prevent overselling. A database-level lock guarantees that only one transaction can modify the same stock row at a time.

## Why Redis Cache Was Used

Redis cache was used to reduce repeated database reads for hot data such as products and admin statistics. The benchmark proves that cached reads are faster than cache misses.

## Why Redis Queue Was Used

Redis Queue was used to move non-critical work outside the main order request path. Invoice generation and notification processing do not need to block the customer order response. This improves responsiveness and separates transactional work from background processing.

## Why Redis Distributed Lock Was Used

Redis distributed lock was used to prevent duplicate batch job execution. If more than one server instance tries to run the batch job at the same time, the lock ensures that only one execution is allowed.

## Why Batch Processing Was Used

Batch processing was used for sales reporting and inventory-oriented background work. This allows the system to process groups of records in a controlled and repeatable way.

## Why Actuator Metrics Were Used

Spring Boot Actuator was used to expose application health and runtime metrics. This supports resource management by making database, Redis, HTTP, JVM thread, and system metrics observable.

## Why Nginx Was Included

Nginx was included because it is a realistic production-grade tool for load balancing. The project also includes an internal weighted round-robin demonstration to prove the distribution concept.

## Stress Test Result

The system passed a 100 concurrent users stress test. Each user performed a full flow involving product browsing, product details retrieval, and order creation. The final result showed zero failed flows, zero server errors, zero timeouts, and correct stock integrity.

## Benchmark Result

The benchmark showed that cached product reads and admin statistics reads are faster than cache misses. The main bottleneck was identified as the transactional order creation path because it intentionally performs several correctness-preserving operations such as authentication, wallet validation, pessimistic locking, persistence, cache eviction, and Redis queue submission.

## Most Important Defense Point

The project is not just a CRUD e-commerce backend. It is a high-performance backend engine focused on non-functional requirements. The most important proof is that correctness was preserved under concurrency and stress, especially stock integrity, transaction rollback, and zero overselling.