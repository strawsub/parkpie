package com.parkpie.backend.parking.repository;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.parkpie.backend.parking.entity.ParkingBayRealtime;

import java.time.LocalDateTime;

public interface ParkingBayRealtimeRepository extends CrudRepository<ParkingBayRealtime, Long> {

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        INSERT INTO public.parking_bay_realtime (kerbsideid, lastupdated, status_timestamp, status_description, zone_number)
        VALUES (:kerbsideId, :lastUpdated, :statusTs, CAST(:statusDesc AS occupancy_status), :zoneNumber)
        ON CONFLICT (kerbsideid) DO UPDATE SET
            lastupdated = EXCLUDED.lastupdated,
            status_timestamp = EXCLUDED.status_timestamp,
            status_description = EXCLUDED.status_description,
            zone_number = EXCLUDED.zone_number
        """, nativeQuery = true)
    int upsert(
            @Param("kerbsideId") long kerbsideId,
            @Param("lastUpdated") LocalDateTime lastUpdated,
            @Param("statusTs") LocalDateTime statusTimestamp,
            @Param("statusDesc") String statusDescription,
            @Param("zoneNumber") Integer zoneNumber
    );
}
