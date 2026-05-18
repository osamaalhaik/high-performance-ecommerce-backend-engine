package com.ecommerce.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.*;

import java.util.Arrays;

@Configuration
@Slf4j
public class LoadBalancerConfig {

    @Bean
    public WeightedRoundRobinLoadBalancer weightedRoundRobinLoadBalancer() {
        return new WeightedRoundRobinLoadBalancer(
                new String[]{"server-1:8081", "server-2:8082", "server-3:8083"},
                new int[]{3, 2, 1}
        );
    }

    public static class WeightedRoundRobinLoadBalancer {

        private final String[] servers;
        private final int[] weights;
        private final int[] counters;
        private int currentIndex = -1;
        private int currentWeight = 0;
        private final int maxWeight;
        private final int gcdWeight;

        public WeightedRoundRobinLoadBalancer(String[] servers, int[] weights) {
            if (servers.length != weights.length) {
                throw new IllegalArgumentException("Servers and weights length must match");
            }

            this.servers = servers;
            this.weights = weights;
            this.counters = new int[servers.length];
            this.maxWeight = Arrays.stream(weights).max().orElse(1);
            this.gcdWeight = calculateGcd(weights);
        }

        public synchronized String nextServer() {
            while (true) {
                currentIndex = (currentIndex + 1) % servers.length;

                if (currentIndex == 0) {
                    currentWeight -= gcdWeight;

                    if (currentWeight <= 0) {
                        currentWeight = maxWeight;
                    }
                }

                if (weights[currentIndex] >= currentWeight) {
                    counters[currentIndex]++;
                    log.debug("[LB] Routing request to {}", servers[currentIndex]);
                    return servers[currentIndex];
                }
            }
        }

        public synchronized String stats() {
            return String.format(
                    "server-1=%d, server-2=%d, server-3=%d",
                    counters[0], counters[1], counters[2]
            );
        }

        private int calculateGcd(int[] values) {
            int result = values[0];

            for (int value : values) {
                result = gcd(result, value);
            }

            return result;
        }

        private int gcd(int a, int b) {
            return b == 0 ? a : gcd(b, a % b);
        }
    }
}