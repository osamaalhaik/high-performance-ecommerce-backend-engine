# Testing Summary

## Postman API Verification

Postman was used to verify health, authentication, product APIs, order creation, customer orders, admin statistics, batch execution, and load balancer server selection.

Evidence path: postman/screenshots

## JMeter Stress Testing

Apache JMeter was used to execute a 100-user stress test.

Final evidence:

- jmeter/100-users-order-stress-test.jmx
- jmeter/screenshots

The final Summary Report proves the expected behavior under concurrent load.

## Database Verification

PostgreSQL evidence proves that users, products, orders, order items, payments, and batch metadata are persisted correctly.

Evidence path: database/screenshots

## Redis Verification

Redis evidence proves that a product cache key was created with a TTL.

Evidence path: redis/screenshots

## Monitoring Verification

Prometheus evidence proves AOP service execution metrics, order counters, Redis queue metrics, batch metrics, and executor metrics.

Evidence path: monitoring/screenshots
