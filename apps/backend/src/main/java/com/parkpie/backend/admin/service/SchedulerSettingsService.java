package com.parkpie.backend.admin.service;

import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class SchedulerSettingsService {

    private volatile boolean enabled = false;
    private volatile long intervalMinutes = 5; // default 5 minutes

    private final AtomicBoolean running = new AtomicBoolean(false);
    private volatile Instant lastRunStart = null;
    private volatile Instant lastRunEnd = null;
    private volatile String lastStatus = "Never run";
    private volatile String lastError = null;
    private final AtomicLong runCount = new AtomicLong(0);

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }

    public long getIntervalMinutes() { return intervalMinutes; }
    public void setIntervalMinutes(long minutes) { this.intervalMinutes = Math.max(1, minutes); }

    public boolean markRunning() { return running.compareAndSet(false, true); }
    public void markFinished() { running.set(false); }
    public boolean isRunning() { return running.get(); }

    public void markStart() { this.lastRunStart = Instant.now(); }
    public void markEndSuccess(String status) {
        this.lastRunEnd = Instant.now();
        this.lastStatus = status;
        this.lastError = null;
        this.runCount.incrementAndGet();
    }
    public void markEndError(String error) {
        this.lastRunEnd = Instant.now();
        this.lastError = error;
    }

    public Instant getLastRunStart() { return lastRunStart; }
    public Instant getLastRunEnd() { return lastRunEnd; }
    public String getLastStatus() { return lastStatus; }
    public String getLastError() { return lastError; }
    public long getRunCount() { return runCount.get(); }

    public long millisUntilNextRun() {
        if (!enabled) return Long.MAX_VALUE;
        Instant ref = lastRunEnd != null ? lastRunEnd : lastRunStart;
        if (ref == null) return 0L;
        long intervalMs = Duration.ofMinutes(intervalMinutes).toMillis();
        long elapsed = Duration.between(ref, Instant.now()).toMillis();
        return Math.max(0, intervalMs - elapsed);
    }
}

