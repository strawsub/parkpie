package com.parkpie.backend.api.dto;

import java.time.OffsetDateTime;

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
