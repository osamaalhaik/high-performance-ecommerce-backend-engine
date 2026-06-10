package com.ecommerce.config;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class LoadBalancerConfigTest {

    @Test
    void weightedRoundRobinDistributesAccordingToWeights() {
        LoadBalancerConfig.WeightedRoundRobinLoadBalancer loadBalancer =
                new LoadBalancerConfig.WeightedRoundRobinLoadBalancer(
                        new String[]{"server-1:8081", "server-2:8082", "server-3:8083"},
                        new int[]{3, 2, 1}
                );

        for (int i = 0; i < 6; i++) {
            assertNotNull(loadBalancer.nextServer());
        }

        assertEquals("server-1=3, server-2=2, server-3=1", loadBalancer.stats());
    }
}
