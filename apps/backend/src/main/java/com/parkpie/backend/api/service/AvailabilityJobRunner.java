package com.parkpie.backend.api.service;

import com.parkpie.backend.api.entity.AvailabilityFetchLog;
import com.parkpie.backend.api.repository.AvailabilityFetchLogRepository;
import org.springframework.stereotype.Service;

/**
 * Coordinates the availability data refresh job and records execution metadata.
 */
@Service
public class AvailabilityJobRunner {

    private final APIDatabaseService dbService;
    private final ParkingSignAggregationService signAggService;
    private final AvailabilityFetchLogRepository logRepo;

    /**
     * Creates the job runner.
     *
     * @param dbService service responsible for ingesting sensor data
     * @param signAggService service that aggregates sign data from realtime occupancy
     * @param logRepo repository that persists execution logs
     */
    public AvailabilityJobRunner(APIDatabaseService dbService,
                                 ParkingSignAggregationService signAggService,
                                 AvailabilityFetchLogRepository logRepo) {
        this.dbService = dbService;
        this.signAggService = signAggService;
        this.logRepo = logRepo;
    }

    /**
     * Runs the job with the default source identifier.
     *
     * @return status message summarising the execution
     */
    public String runOnce() { return runOnce("auto"); }

    /**
     * Run one full cycle: download CSV (filtered to last 5 minutes), update database rows,
     * then rebuild aggregated zone signs. A history log entry is recorded.
     *
     * @param source identifier describing who triggered the run
     * @return status message summarising the execution
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
