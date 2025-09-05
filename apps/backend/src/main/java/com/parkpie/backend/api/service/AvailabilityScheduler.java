package com.parkpie.backend.api.service;

import com.parkpie.backend.admin.service.SchedulerSettingsService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class AvailabilityScheduler {

    private static final Logger log = LoggerFactory.getLogger(AvailabilityScheduler.class);

    private final SchedulerSettingsService settings;
    private final AvailabilityJobRunner runner;

    public AvailabilityScheduler(SchedulerSettingsService settings, AvailabilityJobRunner runner) {
        this.settings = settings;
        this.runner = runner;
    }

    // Check every 30 seconds if we should run (dynamic interval managed in settings)
    @Scheduled(fixedDelay = 30000)
    public void tick() {
        if (!settings.isEnabled()) return;
        if (settings.isRunning()) return;

        long waitMs = settings.millisUntilNextRun();
        if (waitMs > 0) return;

        if (!settings.markRunning()) return;
        try {
            settings.markStart();
            String status = runner.runOnce();
            settings.markEndSuccess(status);
        } catch (Exception e) {
            settings.markEndError(e.getMessage());
        } finally {
            settings.markFinished();
        }
    }
}

