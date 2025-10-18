package com.parkpie.backend;

import com.parkpie.backend.core.controller.HealthController;
import com.parkpie.backend.parking.controller.ParkingSignController;
import com.parkpie.backend.support.PostgresIntegrationTest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.web.SecurityFilterChain;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Smoke tests verifying core beans are created and basic endpoints operate when the context loads.
 */
@SpringBootTest
@EnabledIf("com.parkpie.backend.support.PostgresIntegrationTest#isContainerAvailable")
class ParkPieBackendApplicationTests extends PostgresIntegrationTest {

    @Autowired
    private ParkingSignController parkingSignController;

    @Autowired
    private SecurityFilterChain securityFilterChain;

    @Autowired
    private HealthController healthController;

    @Test
    void contextLoads() {
        assertThat(parkingSignController).isNotNull();
    }

    @Test
    void securityFilterChainConfigured() {
        assertThat(securityFilterChain).isNotNull();
    }

    @Test
    void postgisHealthEndpointProducesPoint() {
        Map<String, Object> response = healthController.postgis();
        assertThat(response).containsKey("point");
        assertThat(response.get("point")).isInstanceOf(String.class);
        assertThat((String) response.get("point")).contains("POINT");
    }
}
