package com.parkpie.backend.api.service;

import com.parkpie.backend.admin.service.SchedulerSettingsService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Periodically triggers the availability refresh job based on scheduler settings.
 */
@Component
public class AvailabilityScheduler {

    private final SchedulerSettingsService settings;
    private final AvailabilityJobRunner runner;

    /**
     * Creates the scheduler.
     *
     * @param settings shared scheduler settings state
     * @param runner job runner that performs the actual refresh
     */
    public AvailabilityScheduler(SchedulerSettingsService settings, AvailabilityJobRunner runner) {
        this.settings = settings;
        this.runner = runner;
    }

    // Check every 30 seconds if we should run (dynamic interval managed in settings)
    /**
     * Invoked by Spring's scheduler to decide whether to run the job.
     */
    @Scheduled(fixedDelay = 30000)
    public void tick() {
        if (!settings.isEnabled()) return;
        if (settings.isRunning()) return;

        long waitMs = settings.millisUntilNextRun();
        if (waitMs > 0) return;

        if (!settings.markRunning()) return;
        try {
            settings.markStart();
            String status = runner.runOnce("auto");
            settings.markEndSuccess(status);
        } catch (Exception e) {
            settings.markEndError(e.getMessage());
        } finally {
            settings.markFinished();
        }
    }
}
