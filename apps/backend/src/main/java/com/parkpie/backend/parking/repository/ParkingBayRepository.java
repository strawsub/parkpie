package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingBay;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ParkingBayRepository extends JpaRepository<ParkingBay, Long> {

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        INSERT INTO parking_bays(street_segment_id, kerbside_id, description, lat, lng, location, last_updated)
        VALUES (:segId, :kerbId, :desc, :lat, :lng, ST_SetSRID(ST_MakePoint(:lng,:lat),4326), :lastUpdated)
        ON CONFLICT (street_segment_id, kerbside_id, lat, lng)
        DO UPDATE SET
            description = EXCLUDED.description,
            last_updated = EXCLUDED.last_updated,
            location = EXCLUDED.location
        """, nativeQuery = true)
    int upsertBay(@Param("segId") long streetSegmentId,
                  @Param("kerbId") long kerbsideId,
                  @Param("desc") String description,
                  @Param("lat") double lat,
                  @Param("lng") double lng,
                  @Param("lastUpdated") java.time.LocalDate lastUpdated);
}
