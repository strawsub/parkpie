package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingSign;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

/**
 * Repository providing spatial lookups and upsert helpers for parking signs.
 */
public interface ParkingSignRepository extends JpaRepository<ParkingSign, Long> {

    /**
     * Projection describing a nearby parking sign.
     */
    interface NearView {
        /**
         * Returns the sign identifier.
         *
         * @return sign identifier
         */
        Long getId();
        /**
         * Returns the human-friendly description for the sign.
         *
         * @return descriptive label for the sign
         */
        String getText();
        /**
         * Returns the latitude in WGS84 decimal degrees.
         *
         * @return latitude in WGS84 decimal degrees
         */
        double getLat();
        /**
         * Returns the longitude in WGS84 decimal degrees.
         *
         * @return longitude in WGS84 decimal degrees
         */
        double getLng();
    }

    /**
     * Projection describing a restriction window near a query point.
     */
    interface RestrictionWindowView {
        /**
         * Returns the zone number associated with the restriction.
         *
         * @return zone number associated with the restriction
         */
        Integer getZoneNumber();
        /**
         * Returns the ISO day-of-week value.
         *
         * @return ISO day-of-week value
         */
        Integer getDayOfWeek();
        /**
         * Returns the restriction start time.
         *
         * @return restriction start time
         */
        java.time.LocalTime getStartTime();
        /**
         * Returns the restriction end time.
         *
         * @return restriction end time
         */
        java.time.LocalTime getEndTime();
        /**
         * Returns the maximum stay minutes.
         *
         * @return maximum stay minutes
         */
        Integer getMaximumStayMinutes();
        /**
         * Returns the distance from the query point in metres.
         *
         * @return distance from the query point in metres
         */
        double getDistanceMeters();
    }

    /**
     * Finds parking signs within a distance of the supplied coordinates.
     *
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param meters search radius in metres
     * @return lightweight projection of nearby signs
     */
    @Query(value = """
        SELECT id, ('Zone ' || COALESCE(zone_number::text,'')) AS text,
               ST_Y(location)::float8 AS lat, ST_X(location)::float8 AS lng
        FROM parking_signs
        WHERE ST_DWithin(location::geography, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :meters)
        """, nativeQuery = true)
    List<NearView> findNear(@Param("lat") double lat, @Param("lng") double lng, @Param("meters") double meters);

    /**
     * Returns restriction windows near the supplied coordinates.
     *
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param meters search radius in metres
     * @return restriction windows ordered by proximity and schedule
     */
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

    /**
     * Removes all sign windows belonging to a zone.
     *
     * @param zoneNumber zone identifier
     * @return number of rows deleted
     */
    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = "DELETE FROM parking_signs WHERE zone_number = :zone", nativeQuery = true)
    int deleteByZone(@Param("zone") int zoneNumber);

    /**
     * Upserts a sign window using realtime occupancy information.
     *
     * @param zoneNumber zone identifier
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param dayOfWeek ISO day-of-week
     * @param startTime start time of the restriction window
     * @param endTime end time of the restriction window
     * @param maximumStay maximum stay in minutes
     * @param occupancyPercent occupancy percentage for the zone
     * @param updatedAt timestamp associated with the occupancy observation
     * @return number of rows inserted or updated
     */
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

    /**
     * Upserts a sign window for manually ingested data.
     *
     * @param zoneNumber zone identifier
     * @param lat latitude in WGS84 decimal degrees
     * @param lng longitude in WGS84 decimal degrees
     * @param dayOfWeek ISO day-of-week
     * @param startTime start time of the restriction window
     * @param endTime end time of the restriction window
     * @param maximumStay maximum stay in minutes
     * @param updatedAt timestamp representing when the manual data was ingested
     * @return number of rows inserted or updated
     */
    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @org.springframework.transaction.annotation.Transactional
    @Query(value = """
        INSERT INTO parking_signs(
            zone_number, location,
            day_of_week, start_time, end_time,
            maximum_stay_minutes, occupancy_percent, updated_at
        ) VALUES (
            :zone, ST_SetSRID(ST_MakePoint(:lng,:lat),4326),
            :dow, :startT, :endT, :maxStay, NULL, :updatedAt
        )
        ON CONFLICT ON CONSTRAINT uq_sign_zone_window DO UPDATE SET
            location = EXCLUDED.location,
            maximum_stay_minutes = EXCLUDED.maximum_stay_minutes,
            updated_at = EXCLUDED.updated_at
        """, nativeQuery = true)
    int upsertManual(@Param("zone") int zoneNumber,
                     @Param("lat") double lat,
                     @Param("lng") double lng,
                     @Param("dow") Integer dayOfWeek,
                     @Param("startT") java.time.LocalTime startTime,
                     @Param("endT") java.time.LocalTime endTime,
                     @Param("maxStay") Integer maximumStay,
                     @Param("updatedAt") java.time.LocalDateTime updatedAt);

    /**
     * Retrieves the next identifier from the manual zone sequence.
     *
     * @return next sequence value
     */
    @Query(value = "SELECT nextval('manual_zone_number_seq')", nativeQuery = true)
    long nextManualZoneSequence();
}
