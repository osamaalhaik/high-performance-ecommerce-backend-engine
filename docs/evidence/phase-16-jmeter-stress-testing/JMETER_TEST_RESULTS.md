# JMeter Stress Testing Results

## Overview

This document summarizes the JMeter stress testing scenarios used to verify concurrency safety, transaction integrity, and overselling prevention in the e-commerce backend engine.

The tested endpoint was:

```http
POST /api/orders

Each request attempted to create an order for the same product with quantity 1.

The tested product was:

Gaming Laptop

Product ID:

0aeccd84-234c-4535-b559-b74c5215b12b

The JMeter test plans are stored under:

jmeter/

The result screenshots are stored under:

jmeter/results/
Scenario 1 - Concurrent Orders 20 Users
Purpose

This scenario verifies that the backend can handle multiple concurrent order requests for the same product without lost updates, race conditions, or overselling.

Configuration
Threads: 20
Ramp-up period: 2 seconds
Loop count: 1
Endpoint: POST /api/orders
Quantity per request: 1
Expected successful orders: 20
Expected Result

Starting stock:

100

Expected final stock:

100 - 20 = 80
Actual Result

The test completed successfully.

Observed result:

Samples = 20
Error % = 0.00%
Final stock = 80

This proves that all 20 concurrent orders were processed successfully and that the product stock was reduced correctly.

Evidence
results/sen1/scenario-1-thread-group-config.png
results/sen1/scenario-1-http-request-config.png
results/sen1/scenario-1-header-manager-config.png
results/sen1/scenario-1-before-stock-100.png
results/sen1/scenario-1-summary-report.png
results/sen1/scenario-1-aggregate-report.png
results/sen1/scenario-1-view-results-all-success.png
results/sen1/scenario-1-after-stock-80.png
Conclusion

Scenario 1 passed. The backend handled 20 concurrent orders without lost updates or overselling.

Scenario 2 - Stress Test 100 Orders
Purpose

This scenario verifies that the backend can handle a higher concurrent load of 100 simultaneous order requests while preserving stock consistency.

Configuration
Threads: 100
Ramp-up period: 5 seconds
Loop count: 1
Endpoint: POST /api/orders
Quantity per request: 1
Expected successful orders: 100
Expected Result

Starting stock:

100

Expected final stock:

100 - 100 = 0
Actual Result

The test completed successfully.

Observed result:

Samples = 100
Error % = 0.00%
Final stock = 0

This confirms that the backend processed 100 concurrent orders correctly and reduced the stock to zero without overselling or data corruption.

Evidence
results/sen2/scenario-2-thread-group-config.png
results/sen2/scenario-2-http-request-config.png
results/sen2/scenario-2-header-manager-config.png
results/sen2/scenario-2-before-stock-100.png
results/sen2/scenario-2-summary-report.png
results/sen2/scenario-2-aggregate-report.png
results/sen2/scenario-2-view-results-all-success.png
results/sen2/scenario-2-after-stock-0.png

Optional additional evidence:

results/sen2/scenario-2-before-stock-100-confirmed.png
results/sen2/scenario-2-reset-stock-100.png
Conclusion

Scenario 2 passed. The backend handled 100 concurrent orders and maintained correct stock integrity.

Scenario 3 - Overselling Attack 100 Requests
Purpose

This scenario verifies that the backend prevents overselling when the number of concurrent purchase requests is higher than the available stock.

Unlike Scenario 1 and Scenario 2, this test expects some requests to be rejected with 409 Conflict after the stock is exhausted. These are business-level rejections, not system failures.

Configuration
Threads: 100
Ramp-up period: 5 seconds
Loop count: 1
Endpoint: POST /api/orders
Quantity per request: 1
Starting stock: 20
Accepted response codes: 201 and 409
Response Assertion

The JMeter Response Assertion accepts both successful orders and insufficient-stock rejections:

^(201|409)$

This means:

201 Created  = order accepted while stock is available
409 Conflict = order rejected after stock is exhausted
Expected Result

Starting stock:

20

Expected behavior:

Only 20 requests should create orders.
Remaining requests should be rejected with 409 Conflict.
Final stock should be 0.
Stock must never become negative.
Actual Result

The test completed successfully.

Observed result:

Samples = 100
201 Created responses were returned before stock exhaustion.
409 Conflict responses were returned after stock exhaustion.
Final stock = 0
No negative stock occurred.

The result proves that the system rejected requests after the available stock was consumed, preventing overselling.

Evidence
results/sen3/scenario-3-thread-group-config.png
results/sen3/scenario-3-http-request-config.png
results/sen3/scenario-3-header-manager-config.png
results/sen3/scenario-3-response-assertion-201-409.png
results/sen3/scenario-3-before-stock-20.png
results/sen3/scenario-3-summary-report.png
results/sen3/scenario-3-aggregate-report.png
results/sen3/scenario-3-view-results-201-409.png
results/sen3/scenario-3-view-result-201-created.png
results/sen3/scenario-3-view-result-409-conflict.png
results/sen3/scenario-3-after-stock-0-no-overselling.png

Optional additional evidence:

results/sen3/scenario-3-before-stock-20-confirmed.png
Conclusion

Scenario 3 passed. The backend prevented overselling by accepting orders only while stock was available and rejecting excess requests with HTTP 409 Conflict.

Final JMeter Results Summary
Scenario	Purpose	Threads	Starting Stock	Expected Final Stock	Actual Result
Scenario 1	Concurrent orders	20	100	80	Passed
Scenario 2	Stress test	100	100	0	Passed
Scenario 3	Overselling attack	100	20	0	Passed
Technical Interpretation

The JMeter tests confirm that the backend preserves data integrity under concurrent load.

The main protection mechanisms are:

Transactional order placement
Pessimistic locking during stock updates
Stock validation before order confirmation
HTTP 409 Conflict for insufficient stock
Controlled concurrent execution through the database transaction boundary

These results prove that the system prevents:

Lost updates
Race conditions on stock quantity
Overselling
Negative stock values
Partial order creation under insufficient stock
Final Conclusion

The JMeter stress tests passed successfully.

The system handled:

20 concurrent users
100 concurrent users
100 overselling attack requests

The backend maintained correct product stock and preserved transactional consistency under concurrent load.











## JMeter Stress Testing Evidence

Evidence folder:

`jmeter/results/`

JMeter documentation:

`jmeter/JMETER_TEST_RESULTS.md`

Evidence:
- Scenario 1 concurrent orders test
- Scenario 2 stress test with 100 orders
- Scenario 3 overselling attack
- Thread group configuration screenshots
- HTTP request configuration screenshots
- Header manager configuration screenshots
- Aggregate reports
- Summary reports
- View Results Tree screenshots
- Before and after stock verification
- 201 Created evidence
- 409 Conflict evidence

