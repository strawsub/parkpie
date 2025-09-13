package com.parkpie.backend.api.service;

import com.parkpie.backend.api.entity.AvailabilityFetchLog;
import com.parkpie.backend.api.repository.AvailabilityFetchLogRepository;
import org.springframework.stereotype.Service;

@Service
public class AvailabilityJobRunner {

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
            dbService.downloadCSV();
            int count = dbService.getRows() != null ? dbService.getRows().size() : 0;
            dbService.updateDatabase();
            int signs = signAggService.rebuildFromRealtime();

            long took = System.currentTimeMillis() - t0;
            String status = "Updated " + count + " rows, signs upserted " + signs + " in " + took + " ms";

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
            throw e;
        }
    }
}
