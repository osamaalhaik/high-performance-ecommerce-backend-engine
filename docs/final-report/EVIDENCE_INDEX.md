# Evidence Index

This document maps each project requirement to its implementation evidence.

## Phase 1 - Environment & Health Verification

Evidence folder:

`docs/evidence/phase-1-environment-health/`

Evidence:
- Maven clean compile success
- Spring Boot application startup
- Actuator health endpoint
- PostgreSQL status UP
- Redis status UP

## Phase 2 - Authentication & Authorization

Evidence folder:

`docs/evidence/phase-2-auth-security/`

Evidence:
- Admin login success
- Customer login success
- Protected customer endpoint with valid token
- Unauthorized request rejection
- Forbidden request for wrong role

## Phase 3 - Product APIs & Validation

Evidence folder:

`docs/evidence/phase-3-product-api-validation/`

Evidence:
- Product listing
- Product by ID
- Input validation
- Invalid quantity rejection

## Phase 4 - Order Flow & Transaction Integrity

Evidence folder:

`docs/evidence/phase-4-order-transaction-integrity/`

Evidence:
- Successful order creation
- Order status CONFIRMED
- Payment simulation
- Stock reduction after order
- User orders endpoint

## Phase 5 - Concurrency Control

Evidence folder:

`docs/evidence/phase-5-concurrency-control/`

Evidence:
- Pessimistic lock implementation
- Optimistic lock conflict
- HTTP 409 conflict response
- Stock never becomes negative

## Phase 6 - Resource Management

Evidence folder:

`docs/evidence/phase-6-resource-management/`

Evidence:
- Thread pool configuration
- Pagination limit
- Hikari connection pool configuration

## Phase 7 - Async Processing

Evidence folder:

`docs/evidence/phase-7-async-processing/`

Evidence:
- Async invoice generation
- Async notification sending
- Separate async thread names

## Phase 8 - Batch Processing

Evidence folder:

`docs/evidence/phase-8-batch-processing/`

Evidence:
- Spring Batch job execution
- Manual batch trigger
- COMPLETED status

## Phase 9 - Load Distribution

Evidence folder:

`docs/evidence/phase-9-load-distribution/`

Evidence:
- Weighted Round Robin implementation
- Multiple next-server responses
- Load balancer stats

## Phase 10 - Redis Caching & Benchmarking

Evidence folder:

`docs/evidence/phase-10-benchmarking/`

Evidence:
- Cache miss log
- Redis key existence
- Cached product retrieval
- Response time comparison