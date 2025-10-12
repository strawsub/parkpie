package com.parkpie.backend.parking.dto;

import java.time.ZonedDateTime;

public record RestrictionDurationResult(
        long durationMinutes,
        Scenario scenario,
        Integer maxStayMinutes,
        Integer zoneNumber,
        double distanceMeters,
        ZonedDateTime restrictionWindowEnd,
        ZonedDateTime nextRestrictionStart
) {

    public enum Scenario {
        ACTIVE_RESTRICTION,
        UNTIL_NEXT_RESTRICTION
    }
}

