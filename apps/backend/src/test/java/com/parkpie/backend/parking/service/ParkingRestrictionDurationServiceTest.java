package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.RestrictionDurationResult;
import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyDouble;

/**
 * Unit tests covering the restriction duration calculation logic.
 */
class ParkingRestrictionDurationServiceTest {

    private ParkingSignRepository repository;
    private ParkingRestrictionDurationService service;

    @BeforeEach
    void setUp() {
        repository = Mockito.mock(ParkingSignRepository.class);
        service = new ParkingRestrictionDurationService(repository);
    }

    @Test
    void returnsMaxStayWhenCurrentlyRestricted() {
        OffsetDateTime startTime = OffsetDateTime.parse("2025-05-07T15:00:00+10:00");
        List<ParkingSignRepository.RestrictionWindowView> windows = List.of(
                window(101, 3, LocalTime.of(8, 0), LocalTime.of(18, 0), 30, 12.0)
        );
        Mockito.when(repository.findRestrictionWindowsNear(anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(windows);

        Optional<RestrictionDurationResult> result = service.calculateDuration(-37.0, 144.0, startTime);

        assertTrue(result.isPresent());
        assertEquals(RestrictionDurationResult.Scenario.ACTIVE_RESTRICTION, result.get().scenario());
        assertEquals(30L, result.get().durationMinutes());
        assertEquals(30, result.get().maxStayMinutes());
        assertFalse(result.get().matchedByZoneId());
    }

    @Test
    void returnsTimeUntilNextRestrictionWhenOutsideWindow() {
        OffsetDateTime startTime = OffsetDateTime.parse("2025-05-07T21:00:00+10:00"); // Wednesday 9pm local
        List<ParkingSignRepository.RestrictionWindowView> windows = List.of(
                window(102, 3, LocalTime.of(8, 0), LocalTime.of(18, 0), 120, 8.0),
                window(102, 4, LocalTime.of(8, 0), LocalTime.of(18, 0), 120, 8.0)
        );
        Mockito.when(repository.findRestrictionWindowsNear(anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(windows);

        Optional<RestrictionDurationResult> result = service.calculateDuration(-37.0, 144.0, startTime);

        assertTrue(result.isPresent());
        assertEquals(RestrictionDurationResult.Scenario.UNTIL_NEXT_RESTRICTION, result.get().scenario());
        assertEquals(11 * 60L, result.get().durationMinutes()); // 11 hours until 8am next day
        assertEquals(102, result.get().zoneNumber());
        assertEquals(120, result.get().maxStayMinutes());
        assertFalse(result.get().matchedByZoneId());
    }

    @Test
    void returnsEmptyWhenNoSignsNearby() {
        OffsetDateTime startTime = OffsetDateTime.parse("2025-05-07T15:00:00+10:00");
        Mockito.when(repository.findRestrictionWindowsNear(anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(Collections.emptyList());

        Optional<RestrictionDurationResult> result = service.calculateDuration(-37.0, 144.0, startTime);

        assertFalse(result.isPresent());
    }

    @Test
    void honoursPreferredZoneWhenPresent() {
        OffsetDateTime startTime = OffsetDateTime.parse("2025-05-07T15:00:00+10:00");
        List<ParkingSignRepository.RestrictionWindowView> windows = List.of(
                window(-200, 3, LocalTime.of(8, 0), LocalTime.of(18, 0), 60, 25.0),
                window(-200, 3, LocalTime.of(18, 0), LocalTime.of(23, 0), null, 25.0),
                window(-101, 3, LocalTime.of(9, 0), LocalTime.of(17, 0), 30, 10.0)
        );
        Mockito.when(repository.findRestrictionWindowsNear(anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(windows);

        Optional<RestrictionDurationResult> result = service.calculateDuration(-37.0, 144.0, startTime, -200);

        assertTrue(result.isPresent());
        assertTrue(result.get().matchedByZoneId());
        assertEquals(-200, result.get().zoneNumber());
    }

    @Test
    void fallsBackToNearestWhenPreferredZoneMissing() {
        OffsetDateTime startTime = OffsetDateTime.parse("2025-05-07T21:00:00+10:00");
        List<ParkingSignRepository.RestrictionWindowView> windows = List.of(
                window(-150, 4, LocalTime.of(7, 0), LocalTime.of(10, 0), 90, 5.0)
        );
        Mockito.when(repository.findRestrictionWindowsNear(anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(windows);

        Optional<RestrictionDurationResult> result = service.calculateDuration(-37.0, 144.0, startTime, -999);

        assertTrue(result.isPresent());
        assertFalse(result.get().matchedByZoneId());
        assertEquals(-150, result.get().zoneNumber());
    }

    private static ParkingSignRepository.RestrictionWindowView window(
            Integer zoneNumber,
            int dayOfWeek,
            LocalTime start,
            LocalTime end,
            Integer maxStay,
            double distance
    ) {
        return new ParkingSignRepository.RestrictionWindowView() {
            @Override
            public Integer getZoneNumber() { return zoneNumber; }
            @Override
            public Integer getDayOfWeek() { return dayOfWeek; }
            @Override
            public LocalTime getStartTime() { return start; }
            @Override
            public LocalTime getEndTime() { return end; }
            @Override
            public Integer getMaximumStayMinutes() { return maxStay; }
            @Override
            public double getDistanceMeters() { return distance; }
        };
    }
}
