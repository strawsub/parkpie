package com.parkpie.backend.api.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class AvailabilityJobRunner {

    private static final Logger log = LoggerFactory.getLogger(AvailabilityJobRunner.class);

    private final APIDatabaseService dbService;

    public AvailabilityJobRunner(APIDatabaseService dbService) {
        this.dbService = dbService;
    }

    /**
     * Run one full cycle: download CSV (filtered to last 5 min) and update database rows.
     * Returns a short status summary.
     */
    public String runOnce() {
        long t0 = System.currentTimeMillis();
        try {
            log.info("[AvailabilityJob] Downloading CSV...");
            dbService.downloadCSV();
            int count = dbService.getRows() != null ? dbService.getRows().size() : 0;
            log.info("[AvailabilityJob] {} recent rows fetched.", count);

            log.info("[AvailabilityJob] Updating database...");
            dbService.updateDatabase();

            long took = System.currentTimeMillis() - t0;
            String status = "Updated " + count + " rows in " + took + " ms";
            log.info("[AvailabilityJob] {}", status);
            return status;
        } catch (Exception e) {
            log.error("[AvailabilityJob] Error during run: {}", e.getMessage(), e);
            throw e;
        }
    }
}

