# Evidence Index

This file maps each final evidence folder to the requirement it proves.

## 1. Postman API Verification

Path: postman/screenshots

Expected files:

- 01-health-db-up.png
- 02-health-redis-up.png
- 03-admin-login-success.png
- 04-postman-customer-register-success.png
- 05-postman-customer-login-success.png
- 06-postman-products-list-success.png
- 07-product-by-id-success.png
- 08-create-order-success.png
- 09-get-my-orders-success.png
- 10-admin-stats-success.png
- 11-batch-job-completed.png
- 12-lb-next-server-1.png
- 13-lb-next-server-2.png
- 14-lb-next-server-3.png

Proves application health, authentication, product APIs, order creation, admin statistics, batch execution, and load balancer endpoint behavior.

## 2. JMeter Stress Testing

Path: jmeter

Important files:

- jmeter/100-users-order-stress-test.jmx
- jmeter/screenshots

Proves 100 concurrent users, stored test plan, stored execution evidence, response assertions, and overselling prevention.

## 3. Database Evidence

Path: database/screenshots

Expected files:

- 01-db-connection-ecommerce-db.png
- 02-db-tables-list.png
- 03-users-roles-wallets.png
- 04-product-stock-version.png
- 05-orders-items-join.png
- 06-batch-job-executions-completed.png
- 07-payments-confirmed.png

Proves database connection, tables, users, roles, wallets, product stock, version field, orders, order items, payments, and batch metadata.

## 4. Redis Cache Evidence

Path: redis/screenshots

Expected file:

- 01-redis-cache-key-ttl-proof.png

Proves Redis availability, product cache key creation, and positive TTL.

## 5. Monitoring and Prometheus Evidence

Path: monitoring/screenshots

Expected files:

- 01-actuator-prometheus-aop-service-metrics.png
- 02-actuator-prometheus-orders-attempts-metrics.png
- 03-actuator-prometheus-orders-success-metrics.png
- 04-actuator-prometheus-orders-failures-metrics.png
- 05-actuator-prometheus-redis-queue-lpop-rpush-metrics.png
- 06-actuator-prometheus-batch-job-metrics.png
- 07-actuator-prometheus-executor-pool-metrics.png
- 08-actuator-prometheus-batch-chunk-write-metrics.png

Proves AOP service execution metrics, order counters, Redis interaction metrics, async queue activity, batch metrics, and executor metrics.

## 6. Infrastructure and Nginx Load Balancing Configuration

Path: infra/nginx/nginx.conf

Proves that the project includes a real Nginx weighted reverse proxy configuration for distributing requests across backend instances.

Screenshot: infra/nginx/screenshots/nginx-weighted-load-balancer-60-requests.png

This screenshot proves the runtime weighted distribution result of 60 requests through Nginx: 30 requests to 9091, 20 requests to 9092, and 10 requests to 9093.
