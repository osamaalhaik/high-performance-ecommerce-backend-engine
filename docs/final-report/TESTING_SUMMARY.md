# Testing Summary

The project was tested in multiple phases to verify both functional and non-functional requirements.

## Compilation Test

Command:

```powershell
.\mvnw clean compile

## JMeter Stress Testing

The system was tested using three JMeter scenarios.

Scenario 1 tested 20 concurrent users. The product stock was reduced from 100 to 80, proving that all 20 orders were processed correctly without lost updates.

Scenario 2 tested 100 concurrent users. The product stock was reduced from 100 to 0, proving that the backend handled high concurrent load while preserving stock integrity.

Scenario 3 tested an overselling attack. The product stock started at 20 while 100 concurrent requests were sent. Only available stock was sold, and the remaining requests were rejected with HTTP 409 Conflict. The final stock remained 0 and never became negative.