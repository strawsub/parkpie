package com.parkpie.backend.api.repository;

import com.parkpie.backend.api.entity.AvailabilityFetchLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * Repository for accessing availability job execution logs.
 */
public interface AvailabilityFetchLogRepository extends JpaRepository<AvailabilityFetchLog, Long> {
    /**
     * Returns the fifty most recent executions ordered by start time descending.
     *
     * @return list of recent log entries
     */
    List<AvailabilityFetchLog> findTop50ByOrderByStartedAtDesc();
}
