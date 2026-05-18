# Architecture Explanation

## Project Overview

The project is a high-performance e-commerce backend engine built using Java Spring Boot. The system focuses on non-functional requirements such as concurrency safety, transaction integrity, caching, asynchronous processing, batch processing, monitoring, and load distribution.

## Main Layers

### Controller Layer

Responsible for exposing REST APIs.

Main controllers:
- AuthController
- ProductController
- OrderController
- AdminController

### Service Layer

Contains the business logic.

Main services:
- AuthService
- ProductService
- OrderService
- InvoiceService
- NotificationService

### Repository Layer

Responsible for database access using Spring Data JPA.

Main repositories:
- UserRepository
- ProductRepository
- OrderRepository
- PaymentRepository

### Persistence Layer

The project uses PostgreSQL as the main relational database.

Main entities:
- User
- Product
- Order
- OrderItem
- Payment

## Security Architecture

The system uses JWT-based stateless authentication.

Security components:
- SecurityConfig
- JwtAuthenticationFilter
- JwtService

Role-based access control is applied using Spring Security and `@PreAuthorize`.

## Concurrency Architecture

The system uses two locking strategies:

### Pessimistic Locking

Used during order placement to protect stock quantity from concurrent modification.

Implemented in:

```java
ProductRepository.findByIdForUpdate()