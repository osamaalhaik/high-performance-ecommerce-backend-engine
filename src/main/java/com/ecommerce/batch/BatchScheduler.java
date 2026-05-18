package com.ecommerce.batch;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.*;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
@RequiredArgsConstructor
@Slf4j
public class BatchScheduler {

    private final JobLauncher jobLauncher;
    private final Job dailySalesReportJob;

    public String runManually() {
        try {
            JobParameters parameters = new JobParametersBuilder()
                    .addString("triggeredBy", "manual-admin-api")
                    .addLocalDateTime("runAt", LocalDateTime.now())
                    .toJobParameters();

            log.info("[BATCH] Manual execution requested | job={}", dailySalesReportJob.getName());

            JobExecution execution = jobLauncher.run(dailySalesReportJob, parameters);

            log.info(
                    "[BATCH] Manual execution finished | job={} | status={} | exitStatus={}",
                    dailySalesReportJob.getName(),
                    execution.getStatus(),
                    execution.getExitStatus().getExitCode()
            );

            return "Batch executed successfully | status="
                    + execution.getStatus()
                    + " | exitStatus="
                    + execution.getExitStatus().getExitCode();

        } catch (Exception ex) {
            log.error("[BATCH] Manual execution failed", ex);
            return "Batch execution failed: " + ex.getMessage();
        }
    }
}