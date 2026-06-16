# Requirements Mapping

| Requirement | Implementation Evidence | Visual or Runtime Evidence |
|---|---|---|
| Concurrent Access and Data Integrity | Transactional order creation, stock validation, wallet validation, repository locking | JMeter results, database order and stock screenshots |
| Resource Management and Capacity Control | Executor configuration, Hikari connection pool, metrics exposure | Monitoring screenshots for executor and runtime metrics |
| Asynchronous Processing | Async invoice and notification flow, Redis queue metrics | Monitoring Redis queue metrics |
| Batch Processing | Spring Batch daily sales job | Postman batch run screenshot, database batch execution screenshot, Prometheus batch metrics |
| Load Distribution | Load balancer server selection endpoint and weighted strategy | Postman load balancer screenshots for server-1, server-2, and server-3 |
| Distributed Caching | Redis product cache with TTL | Redis cache key TTL screenshot, Postman Redis health screenshot |
| Locking and Concurrency Control | Pessimistic product and wallet locking | JMeter overselling prevention evidence, database stock and version evidence |
| Transaction Integrity and ACID | Order, order items, payment, wallet and stock updates handled transactionally | Postman order success, database orders, items, and payments screenshots |
| Stress Testing | JMeter 100 users plan and result evidence | JMeter screenshots |
| Benchmarking and Bottleneck Analysis | Service timing metrics and final bottleneck notes | Prometheus AOP service metrics and benchmark report |
| AOP Monitoring | Performance monitoring aspect exposes service execution metrics | ecommerce service execution metrics screenshot |
