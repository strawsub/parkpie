package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.PayStayRestriction;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;

public interface PayStayRestrictionRepository extends JpaRepository<PayStayRestriction, Long> {

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
