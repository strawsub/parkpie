package com.parkpie.backend.parking.dto;

import java.time.ZonedDateTime;

/**
 * Represents the outcome of a parking restriction duration calculation.
 *
 * @param durationMinutes        number of minutes the vehicle may remain parked
 * @param scenario               outcome scenario describing whether a restriction is active now or upcoming
 * @param maxStayMinutes         optional maximum stay defined by the matched restriction
 * @param zoneNumber             zone number associated with the result
 * @param distanceMeters         distance from the query point to the matched restriction
 * @param restrictionWindowEnd   end timestamp for the active restriction window, when applicable
 * @param nextRestrictionStart   start timestamp for the next restriction window, when applicable
 * @param matchedByZoneId        whether the result favoured a caller-specified zone
 */
public record RestrictionDurationResult(
        long durationMinutes,
        Scenario scenario,
        Integer maxStayMinutes,
        Integer zoneNumber,
        double distanceMeters,
        ZonedDateTime restrictionWindowEnd,
        ZonedDateTime nextRestrictionStart,
        boolean matchedByZoneId
) {

    /**
     * Scenarios describing the type of restriction calculation result.
     */
    public enum Scenario {
        /** A restriction window is currently active. */
        ACTIVE_RESTRICTION,
        /** No restriction is active; value indicates waiting time until the next restriction. */
        UNTIL_NEXT_RESTRICTION
    }
}
