# JMeter Test Plans

## 100-users-order-stress-test.jmx

This test plan validates the main high-concurrency backend flow:

1. Register customer
2. Extract JWT token
3. Read product from catalog
4. Place order for the configured product

Before running the plan, replace the variable `product_id` with a real product id created in the running application.

Recommended execution:

jmeter -n -t jmeter/100-users-order-stress-test.jmx -l jmeter/results/100-users-order-stress-test.jtl -e -o jmeter/results/html-report
