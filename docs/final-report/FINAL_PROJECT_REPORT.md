# Final Project Report

## Project Title

High-Performance E-Commerce Backend Engine

## Course

Parallel Programming - 2026

## Technology Stack

The project was implemented using Java Spring Boot as the main backend framework.

Main technologies used:

- Java 17
- Spring Boot
- Spring Web
- Spring Security
- JWT Authentication
- Spring Data JPA
- PostgreSQL
- Redis
- Spring Cache
- Spring Batch
- Spring Async
- Spring AOP
- Micrometer
- Spring Boot Actuator
- JMeter

---

## 1. Project Overview

This project implements a high-performance backend engine for an e-commerce system. The project focuses mainly on non-functional requirements such as concurrency safety, transaction integrity, resource management, asynchronous processing, batch processing, caching, monitoring, and load distribution.

The system supports essential e-commerce operations such as user authentication, product retrieval, stock management, order placement, payment simulation, and administrative operations. These functional features were designed mainly to demonstrate and test the required non-functional concepts under realistic backend conditions.

---

## 2. System Architecture

The project follows a layered backend architecture.

### Controller Layer

The controller layer exposes REST APIs to external clients.

Main controllers:

- AuthController
- ProductController
- OrderController
- AdminController

### Service Layer

The service layer contains the core business logic.

Main services:

- AuthService
- ProductService
- OrderService
- InvoiceService
- NotificationService

### Repository Layer

The repository layer handles database access using Spring Data JPA.

Main repositories:

- UserRepository
- ProductRepository
- OrderRepository
- PaymentRepository

### Persistence Layer

The system uses PostgreSQL as the main relational database.

Main entities:

- User
- Product
- Order
- OrderItem
- Payment

### Infrastructure Layer

The project also includes infrastructure-level components:

- RedisConfig for distributed caching
- AsyncConfig for thread pool management
- LoadBalancerConfig for load distribution simulation
- PerformanceMonitoringAspect for AOP-based monitoring
- BatchScheduler and batch job configuration for background batch processing

---

## 3. Authentication and Authorization

The system uses JWT-based stateless authentication.

Users can log in and receive a JWT token. This token is then sent in the Authorization header using the Bearer scheme.

Security is implemented using:

- SecurityConfig
- JwtAuthenticationFilter
- JwtService

Role-based access control is applied using Spring Security. Admin endpoints are restricted to users with the ADMIN role, while customer operations require authenticated users.

The tests verified:

- Admin login
- Customer login
- Valid token access
- Invalid token rejection
- Unauthorized access rejection
- Customer access prevention on admin endpoints

---

## 4. Concurrent Access and Data Integrity

One of the main goals of the project is to protect shared data from race conditions, especially product stock quantity.

The system protects stock updates during order placement by using pessimistic locking.

The ProductRepository contains a method that locks the product row before modifying stock:

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT p FROM Product p WHERE p.id = :id")
Optional<Product> findByIdForUpdate(@Param("id") String id);




## Stress Testing

The system was tested using JMeter.

### Scenario 1 - 20 Concurrent Orders

Result:
- Starting stock: 100
- Final stock: 80
- Error rate: 0.00%
- No lost update
- No overselling

### Scenario 2 - 100 Concurrent Orders

Result:
- Starting stock: 100
- Final stock: 0
- Error rate: 0.00%
- No overselling
- No data corruption

### Scenario 3 - Overselling Attack

The product stock was set to 20, then 100 concurrent purchase requests were sent.

Result:
- 201 Created responses occurred while stock was available.
- 409 Conflict responses occurred after stock was exhausted.
- Final stock remained 0.
- No negative stock occurred.
- No overselling occurred.