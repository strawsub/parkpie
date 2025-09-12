package com.parkpie.backend.api.service;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AvailabilityFetchLogRepository extends JpaRepository<AvailabilityFetchLog, Long> {
    List<AvailabilityFetchLog> findTop50ByOrderByStartedAtDesc();
}

