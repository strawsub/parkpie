package com.parkpie.backend.admin.service;

import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Manages mutable scheduler settings and runtime status in a thread-safe fashion for the
 * availability fetch job.
 */
@Service
public class SchedulerSettingsService {

    private volatile boolean enabled = false;
    private volatile long intervalMinutes = 5; // default 5 minutes

    private final AtomicBoolean running = new AtomicBoolean(false);
    private volatile LocalDateTime lastRunStart = null;
    private volatile LocalDateTime lastRunEnd = null;
    private volatile String lastStatus = "Never run";
    private volatile String lastError = null;
    private final AtomicLong runCount = new AtomicLong(0);

    /**
     * Creates the scheduler settings container with default values.
     */
    public SchedulerSettingsService() {
    }

    /**
     * Indicates whether scheduled executions are enabled.
     *
     * @return {@code true} when the scheduler is allowed to trigger jobs
     */
    public boolean isEnabled() { return enabled; }

    /**
     * Enables or disables scheduled executions.
     *
     * @param enabled {@code true} to allow scheduled executions
     */
    public void setEnabled(boolean enabled) { this.enabled = enabled; }

    /**
     * Returns the configured interval between scheduled runs in minutes.
     *
     * @return polling interval in minutes
     */
    public long getIntervalMinutes() { return intervalMinutes; }

    /**
     * Updates the scheduler interval, enforcing a minimum of one minute.
     *
     * @param minutes requested interval in minutes
     */
    public void setIntervalMinutes(long minutes) { this.intervalMinutes = Math.max(1, minutes); }

    /**
     * Attempts to mark the job as running.
     *
     * @return {@code true} if the job transitioned to running state
     */
    public boolean markRunning() { return running.compareAndSet(false, true); }

    /**
     * Marks the scheduler as idle.
     */
    public void markFinished() { running.set(false); }

    /**
     * Indicates whether a job is currently running.
     *
     * @return {@code true} if a job is in progress
     */
    public boolean isRunning() { return running.get(); }

    /**
     * Records the start time of a job execution.
     */
    public void markStart() { this.lastRunStart = LocalDateTime.now(); }

    /**
     * Records a successful job completion.
     *
     * @param status status message describing the outcome
     */
    public void markEndSuccess(String status) {
        this.lastRunEnd = LocalDateTime.now();
        this.lastStatus = status;
        this.lastError = null;
        this.runCount.incrementAndGet();
    }

    /**
     * Records a failed job completion.
     *
     * @param error error message describing the failure
     */
    public void markEndError(String error) {
        this.lastRunEnd = LocalDateTime.now();
        this.lastError = error;
    }

    /**
     * Returns the timestamp of the last job start.
     *
     * @return last job start or {@code null} if never run
     */
    public LocalDateTime getLastRunStart() { return lastRunStart; }

    /**
     * Returns the timestamp of the last job completion.
     *
     * @return last job end or {@code null} if never run
     */
    public LocalDateTime getLastRunEnd() { return lastRunEnd; }

    /**
     * Returns the status message from the most recent execution.
     *
     * @return status message
     */
    public String getLastStatus() { return lastStatus; }

    /**
     * Returns the most recent failure message, if any.
     *
     * @return error message or {@code null} when successful
     */
    public String getLastError() { return lastError; }

    /**
     * Returns the number of successful runs since startup.
     *
     * @return count of completed runs
     */
    public long getRunCount() { return runCount.get(); }

    /**
     * Calculates the milliseconds remaining before the next scheduled execution should trigger.
     *
     * @return milliseconds until the next run or {@link Long#MAX_VALUE} when disabled
     */
    public long millisUntilNextRun() {
        if (!enabled) return Long.MAX_VALUE;
        LocalDateTime ref = lastRunEnd != null ? lastRunEnd : lastRunStart;
        if (ref == null) return 0L;
        long intervalMs = Duration.ofMinutes(intervalMinutes).toMillis();
        long elapsed = Duration.between(ref, LocalDateTime.now()).toMillis();
        return Math.max(0, intervalMs - elapsed);
    }
}
