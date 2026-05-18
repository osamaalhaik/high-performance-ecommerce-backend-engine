package com.ecommerce.batch;

import com.ecommerce.entity.Order;
import com.ecommerce.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.batch.item.ItemReader;
import org.springframework.batch.item.ItemWriter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

import java.time.LocalDateTime;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.DoubleAdder;

@Configuration
@RequiredArgsConstructor
@Slf4j
public class DailySalesBatchConfig {

    private final OrderRepository orderRepository;
    private final JobRepository jobRepository;
    private final PlatformTransactionManager transactionManager;

    @Bean
    @StepScope
    public ItemReader<Order> dailySalesReader() {

        return new ItemReader<>() {

            private Iterator<Order> iterator;
            private boolean initialized = false;

            @Override
            public Order read() {

                if (!initialized) {

                    LocalDateTime start =
                            LocalDateTime.now()
                                    .withHour(0)
                                    .withMinute(0)
                                    .withSecond(0)
                                    .withNano(0);

                    LocalDateTime end = LocalDateTime.now();

                    List<Order> orders =
                            orderRepository.findConfirmedOrdersBetween(start, end);

                    iterator = orders.iterator();
                    initialized = true;

                    log.info(
                            "[BATCH-READER] Loaded {} confirmed orders",
                            orders.size()
                    );
                }

                return iterator.hasNext()
                        ? iterator.next()
                        : null;
            }
        };
    }

    @Bean
    public ItemProcessor<Order, SalesSummary> dailySalesProcessor() {

        return order -> {

            double revenue =
                    order.getTotalAmount();

            int itemCount =
                    order.getItems() == null
                            ? 0
                            : order.getItems().size();

            SalesSummary summary = new SalesSummary(
                    order.getId(),
                    order.getUser().getEmail(),
                    revenue,
                    itemCount,
                    order.getCreatedAt()
            );

            log.debug(
                    "[BATCH-PROCESSOR] Processed order {}",
                    order.getId()
            );

            return summary;
        };
    }

    @Bean
    public ItemWriter<SalesSummary> dailySalesWriter() {

        AtomicInteger totalOrders = new AtomicInteger(0);
        DoubleAdder totalRevenue = new DoubleAdder();

        return chunk -> {

            for (SalesSummary summary : chunk.getItems()) {

                totalOrders.incrementAndGet();

                totalRevenue.add(summary.revenue());
            }

            log.info(
                    "[BATCH-WRITER] Chunk processed | orders={} | revenue={}",
                    totalOrders.get(),
                    totalRevenue.sum()
            );

        };
    }

    @Bean
    public Step dailySalesStep() {

        return new StepBuilder(
                "dailySalesStep",
                jobRepository
        )
                .<Order, SalesSummary>chunk(
                        50,
                        transactionManager
                )
                .reader(dailySalesReader())
                .processor(dailySalesProcessor())
                .writer(dailySalesWriter())
                .faultTolerant()
                .skip(Exception.class)
                .skipLimit(10)
                .build();
    }

    @Bean
    public Job dailySalesReportJob() {

        return new JobBuilder(
                "dailySalesReportJob",
                jobRepository
        )
                .start(dailySalesStep())
                .build();
    }

    public record SalesSummary(
            String orderId,
            String userEmail,
            double revenue,
            int itemCount,
            LocalDateTime createdAt
    ) {
    }
}