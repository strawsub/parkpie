package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.PayStayRestriction;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;

/**
 * Repository managing PayStay restriction windows.
 */
public interface PayStayRestrictionRepository extends JpaRepository<PayStayRestriction, Long> {

    /**
     * Upserts a PayStay restriction window using its natural key.
     *
     * @param zone PayStay zone identifier
     * @param dayOfWeek ISO day-of-week
     * @param startTime start time of the restriction window
     * @param endTime end time of the restriction window
     * @param minimumStayMinutes minimum stay minutes, nullable
     * @param maximumStayMinutes maximum stay minutes
     * @param costPerHourCents hourly cost in cents
     * @param dayOfWeekName friendly day-of-week label
     * @return number of rows inserted or updated
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        INSERT INTO pay_stay_restrictions(pay_stay_zone, day_of_week, start_time, end_time,
                                          minimum_stay_minutes, maximum_stay_minutes, cost_per_hour_cents, day_of_week_name)
        VALUES (:zone, :dow, :startT, :endT, :minStay, :maxStay, :cents, :dowName)
        ON CONFLICT (pay_stay_zone, day_of_week, start_time, end_time)
        DO UPDATE SET
            minimum_stay_minutes = EXCLUDED.minimum_stay_minutes,
            maximum_stay_minutes = EXCLUDED.maximum_stay_minutes,
            cost_per_hour_cents = EXCLUDED.cost_per_hour_cents,
            day_of_week_name = EXCLUDED.day_of_week_name
        """, nativeQuery = true)
    int upsertRestriction(@Param("zone") String zone,
                          @Param("dow") int dayOfWeek,
                          @Param("startT") LocalTime startTime,
                          @Param("endT") LocalTime endTime,
                          @Param("minStay") Integer minimumStayMinutes,
                          @Param("maxStay") int maximumStayMinutes,
                          @Param("cents") int costPerHourCents,
                          @Param("dowName") String dayOfWeekName);
}
