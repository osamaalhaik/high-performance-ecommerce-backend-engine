

<!-- AUTO-JMETER-STRESS-START -->
## JMeter 100 Users Stress Test and Bottleneck Analysis

A 100-user JMeter stress test was executed on the backend using a scenario composed of Register Customer, Read Product From Catalog, and Place Order. The test produced 300 total samples.

Before capacity tuning, the system preserved stock integrity but exposed a bottleneck in the Place Order path. The first run produced 17 failed samples out of 300, with an error rate of 5.67%. Stock integrity remained correct because the stock moved from 1000 to 916, matching 84 successful order requests.

After capacity tuning, Hikari maximum-pool-size was increased from 20 to 50, Hikari connection-timeout from 30000ms to 180000ms, and async queue-capacity from 100 to 300. The final run completed 300 successful samples out of 300, with 0% error rate. The Place Order request completed 100 successful orders and the stock moved from 1000 to 900, exactly matching the expected stock value after successful orders.

This evidence proves stress testing, bottleneck analysis, resource capacity management, ACID transaction integrity, and shared stock protection under concurrent access.

Detailed evidence is available in:

- docs/final-report/JMETER_100_USERS_STRESS_TEST_AND_BOTTLENECK_ANALYSIS.md
- docs/evidence/step-04-jmeter-100-users-final/
- docs/evidence/step-05-jmeter-100-users-capacity-tuned/
- jmeter/results/100-users-capacity-tuned-20260611-142546/html-report/index.html
<!-- AUTO-JMETER-STRESS-END -->
