package com.parkpie.backend.api.dto;

import java.time.OffsetDateTime;

/**
 * API response describing the outcome of a restriction duration calculation.
 *
 * @param durationMinutes        number of minutes the vehicle may remain parked
 * @param scenario               scenario identifier (active restriction or until next restriction)
 * @param maxStayMinutes         optional maximum stay imposed by the restriction
 * @param zoneNumber             zone number matched for the calculation
 * @param distanceMeters         distance from the query point to the matched restriction
 * @param restrictionWindowEnd   end timestamp for the active restriction window, when applicable
 * @param nextRestrictionStart   start timestamp for the next restriction window, when applicable
 * @param matchedByZoneId        whether the caller-specified zone influenced the result
 */
public record RestrictionDurationApiResponse(
        long durationMinutes,
        String scenario,
        Integer maxStayMinutes,
        Integer zoneNumber,
        double distanceMeters,
        OffsetDateTime restrictionWindowEnd,
        OffsetDateTime nextRestrictionStart,
        boolean matchedByZoneId
) {}
