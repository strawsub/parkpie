package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingSign;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ParkingSignRepository extends JpaRepository<ParkingSign, Long> {

    interface NearView {
        Long getId();
        String getText();
        double getLat();
        double getLng();
    }

    interface RestrictionWindowView {
        Integer getZoneNumber();
        Integer getDayOfWeek();
        java.time.LocalTime getStartTime();
        java.time.LocalTime getEndTime();
        Integer getMaximumStayMinutes();
        double getDistanceMeters();
    }

    @Query(value = """
        SELECT id, ('Zone ' || COALESCE(zone_number::text,'')) AS text,
               ST_Y(location)::float8 AS lat, ST_X(location)::float8 AS lng
        FROM parking_signs
        WHERE ST_DWithin(location::geography, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :meters)
        """, nativeQuery = true)
    List<NearView> findNear(@Param("lat") double lat, @Param("lng") double lng, @Param("meters") double meters);

    @Query(value = """
        SELECT
            zone_number AS zoneNumber,
            day_of_week AS dayOfWeek,
            start_time AS startTime,
            end_time AS endTime,
            maximum_stay_minutes AS maximumStayMinutes,
            ST_Distance(
                location::geography,
                ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
            )::float8 AS distanceMeters
        FROM parking_signs
        WHERE ST_DWithin(
            location::geography,
            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
            :meters
        )
        ORDER BY distanceMeters ASC, zone_number ASC, day_of_week ASC, start_time ASC
        """, nativeQuery = true)
    List<RestrictionWindowView> findRestrictionWindowsNear(
            @Param("lat") double lat,
            @Param("lng") double lng,
            @Param("meters") double meters);

    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = "DELETE FROM parking_signs WHERE zone_number = :zone", nativeQuery = true)
    int deleteByZone(@Param("zone") int zoneNumber);

    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = """
        INSERT INTO parking_signs(
            zone_number, location,
            day_of_week, start_time, end_time,
            maximum_stay_minutes,
            occupancy_percent, updated_at
        ) VALUES (
            :zone, ST_SetSRID(ST_MakePoint(:lng,:lat),4326),
            :dow, :startT, :endT, :maxStay,
            :occupancyPercent, :updatedAt
        )
        ON CONFLICT ON CONSTRAINT uq_sign_zone_window DO UPDATE SET
            location = EXCLUDED.location,
            maximum_stay_minutes = EXCLUDED.maximum_stay_minutes,
            occupancy_percent = EXCLUDED.occupancy_percent,
            updated_at = EXCLUDED.updated_at
        """, nativeQuery = true)
    int upsertSign(@Param("zone") int zoneNumber,
                   @Param("lat") double lat,
                   @Param("lng") double lng,
                   @Param("dow") Integer dayOfWeek,
                   @Param("startT") java.time.LocalTime startTime,
                   @Param("endT") java.time.LocalTime endTime,
                   @Param("maxStay") Integer maximumStay,
                   @Param("occupancyPercent") Double occupancyPercent,
                   @Param("updatedAt") java.time.LocalDateTime updatedAt);

    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = """
        INSERT INTO parking_signs(
            zone_number, location,
            day_of_week, start_time, end_time,
            maximum_stay_minutes, occupancy_percent, updated_at
        ) VALUES (
            :zone, ST_SetSRID(ST_MakePoint(:lng,:lat),4326),
            :dow, :startT, :endT, :maxStay, NULL, NULL
        )
        ON CONFLICT ON CONSTRAINT uq_sign_zone_window DO UPDATE SET
            location = EXCLUDED.location,
            maximum_stay_minutes = EXCLUDED.maximum_stay_minutes
        """, nativeQuery = true)
    int upsertManual(@Param("zone") int zoneNumber,
                     @Param("lat") double lat,
                     @Param("lng") double lng,
                     @Param("dow") Integer dayOfWeek,
                     @Param("startT") java.time.LocalTime startTime,
                     @Param("endT") java.time.LocalTime endTime,
                     @Param("maxStay") Integer maximumStay);

    @Query(value = "SELECT nextval('manual_zone_number_seq')", nativeQuery = true)
    long nextManualZoneSequence();
}
