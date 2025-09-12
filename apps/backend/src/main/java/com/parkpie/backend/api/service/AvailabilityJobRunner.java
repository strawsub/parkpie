package com.parkpie.backend.api.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
public class AvailabilityJobRunner {

    private static final Logger log = LoggerFactory.getLogger(AvailabilityJobRunner.class);

    private final APIDatabaseService dbService;
    private final ParkingSignAggregationService signAggService;
    private final AvailabilityFetchLogRepository logRepo;

    public AvailabilityJobRunner(APIDatabaseService dbService,
                                 ParkingSignAggregationService signAggService,
                                 AvailabilityFetchLogRepository logRepo) {
        this.dbService = dbService;
        this.signAggService = signAggService;
        this.logRepo = logRepo;
    }

    public String runOnce() { return runOnce("auto"); }

    /**
     * Run one full cycle: download CSV (filtered to last 5 min), update database rows,
     * then rebuild aggregated zone signs. A history log entry is recorded.
     */
    public String runOnce(String source) {
        long t0 = System.currentTimeMillis();
        AvailabilityFetchLog entry = new AvailabilityFetchLog();
        entry.setSource(source);
        entry.setStartedAt(java.time.LocalDateTime.now());
        entry.setStatus("RUNNING");
        entry = logRepo.save(entry);
        try {
            log.info("[AvailabilityJob] ({}) Downloading CSV...", source);
            dbService.downloadCSV();
            int count = dbService.getRows() != null ? dbService.getRows().size() : 0;
            log.info("[AvailabilityJob] {} recent rows fetched.", count);

            log.info("[AvailabilityJob] Updating realtime table...");
            dbService.updateDatabase();

            log.info("[AvailabilityJob] Rebuilding zone signs...");
            int signs = signAggService.rebuildFromRealtime();

            long took = System.currentTimeMillis() - t0;
            String status = "Updated " + count + " rows, signs upserted " + signs + " in " + took + " ms";
            log.info("[AvailabilityJob] {}", status);

            entry.setEndedAt(java.time.LocalDateTime.now());
            entry.setRowsFetched(count);
            entry.setSignsUpserted(signs);
            entry.setStatus("SUCCESS");
            entry.setMessage(status);
            logRepo.save(entry);
            return status;
        } catch (Exception e) {
            entry.setEndedAt(java.time.LocalDateTime.now());
            entry.setStatus("ERROR");
            entry.setError(e.getMessage());
            logRepo.save(entry);
            log.error("[AvailabilityJob] Error during run: {}", e.getMessage(), e);
            throw e;
        }
    }
}
