# Defense Notes

## Core Defense Statement

This project is not a UI-focused e-commerce application. It is a high-performance backend engine designed to prove non-functional requirements under concurrent access and operational load.

## Key Defense Points

### Why PostgreSQL?

PostgreSQL is used for durable transactional persistence. It stores users, products, orders, order items, payments, and batch execution metadata.

### Why Redis?

Redis is used for cache evidence and fast key-value access. The final Redis proof shows a product cache key with TTL.

### Why JMeter?

JMeter proves system behavior under 100 concurrent users. The plan and screenshots are stored inside the project.

### Why 409 is Valid in JMeter?

409 Conflict is valid when the system rejects an order safely due to business constraints such as insufficient stock. In stress testing, this is safer than overselling.

### Why Batch Processing?

Batch processing is used to execute reporting-style workloads over confirmed orders. Evidence exists in Postman, database metadata, and Prometheus metrics.

### Why AOP Monitoring?

AOP monitoring records service execution timing without polluting service business logic. Prometheus exposes these metrics for verification.

### Why Load Distribution?

The load balancer endpoint demonstrates controlled server selection and proves the load distribution strategy.

### Why Locking?

Locking protects product stock and wallet balance from concurrent modification anomalies.

## Final Defense Conclusion

The project satisfies the required non-functional concepts through implemented backend logic, API verification, stress testing, database proof, Redis proof, and monitoring metrics.
