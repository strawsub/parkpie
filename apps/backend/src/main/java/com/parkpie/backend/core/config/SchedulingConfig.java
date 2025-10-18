package com.parkpie.backend.core.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Enables Spring's scheduled task support for the application.
 */
@Configuration
@EnableScheduling
public class SchedulingConfig {

    /**
     * Creates the scheduling configuration.
     */
    public SchedulingConfig() {
    }
}
