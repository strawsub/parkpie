package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingBay;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * Repository for persisting and updating parking bay information sourced from CSV feeds.
 */
public interface ParkingBayRepository extends JpaRepository<ParkingBay, Long> {

    /**
     * Upserts a parking bay identified by street segment and kerbside identifiers.
     *
     * @param streetSegmentId street segment identifier
     * @param kerbsideId kerbside identifier
     * @param description street description
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param lastUpdated dataset update timestamp
     * @return number of rows inserted or updated
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        INSERT INTO parking_bays(street_segment_id, kerbside_id, description, lat, lng, location, last_updated)
        VALUES (:segId, :kerbId, :desc, :lat, :lng, ST_SetSRID(ST_MakePoint(:lng,:lat),4326), :lastUpdated)
        ON CONFLICT (street_segment_id, kerbside_id)
        DO UPDATE SET
            description = EXCLUDED.description,
            last_updated = EXCLUDED.last_updated,
            lat = EXCLUDED.lat,
            lng = EXCLUDED.lng,
            location = EXCLUDED.location
        """, nativeQuery = true)
    int upsertBay(@Param("segId") long streetSegmentId,
                  @Param("kerbId") Long kerbsideId,
                  @Param("desc") String description,
                  @Param("lat") double lat,
                  @Param("lng") double lng,
                  @Param("lastUpdated") java.time.LocalDate lastUpdated);

    // For rows without KerbsideID: try to update by (segment, lat, lng, kerbside_id IS NULL); if nothing updated, insert
    /**
     * Attempts to update a parking bay lacking a kerbside identifier, matching on coordinates.
     *
     * @param streetSegmentId street segment identifier
     * @param description street description
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param lastUpdated dataset update timestamp
     * @return number of rows updated
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        UPDATE parking_bays
        SET description = :desc,
            last_updated = :lastUpdated,
            location = ST_SetSRID(ST_MakePoint(:lng,:lat),4326)
        WHERE street_segment_id = :segId
          AND kerbside_id IS NULL
          AND lat = :lat
          AND lng = :lng
        """, nativeQuery = true)
    int updateBayWithoutKerbside(@Param("segId") long streetSegmentId,
                                 @Param("desc") String description,
                                 @Param("lat") double lat,
                                 @Param("lng") double lng,
                                 @Param("lastUpdated") java.time.LocalDate lastUpdated);

    /**
     * Inserts a new parking bay lacking a kerbside identifier.
     *
     * @param streetSegmentId street segment identifier
     * @param description street description
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param lastUpdated dataset update timestamp
     * @return number of rows inserted
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        INSERT INTO parking_bays(street_segment_id, kerbside_id, description, lat, lng, location, last_updated)
        VALUES (:segId, NULL, :desc, :lat, :lng, ST_SetSRID(ST_MakePoint(:lng,:lat),4326), :lastUpdated)
        """, nativeQuery = true)
    int insertBayWithoutKerbside(@Param("segId") long streetSegmentId,
                                 @Param("desc") String description,
                                 @Param("lat") double lat,
                                 @Param("lng") double lng,
                                 @Param("lastUpdated") java.time.LocalDate lastUpdated);
}
