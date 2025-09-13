package com.parkpie.backend.api.repository;

import com.parkpie.backend.api.entity.AvailabilityFetchLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AvailabilityFetchLogRepository extends JpaRepository<AvailabilityFetchLog, Long> {
    List<AvailabilityFetchLog> findTop50ByOrderByStartedAtDesc();
}

