package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.RestrictionDurationResult;
import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class ParkingRestrictionDurationService {

    public static final ZoneId MELBOURNE_ZONE = ZoneId.of("Australia/Melbourne");
    private static final double DEFAULT_SEARCH_RADIUS_METERS = 100.0;

    private final ParkingSignRepository parkingSignRepository;

    public ParkingRestrictionDurationService(ParkingSignRepository parkingSignRepository) {
        this.parkingSignRepository = parkingSignRepository;
    }

    public Optional<RestrictionDurationResult> calculateDuration(
            double lat,
            double lng,
            OffsetDateTime startTime
    ) {
        Objects.requireNonNull(startTime, "startTime");
        ZonedDateTime localStart = startTime.atZoneSameInstant(MELBOURNE_ZONE);

        List<ParkingSignRepository.RestrictionWindowView> windows = parkingSignRepository
                .findRestrictionWindowsNear(lat, lng, DEFAULT_SEARCH_RADIUS_METERS);

        ParkingSignRepository.RestrictionWindowView nearest = windows.stream()
                .filter(view -> view.getZoneNumber() != null)
                .findFirst()
                .orElse(null);

        if (nearest == null) {
            return Optional.empty();
        }

        Integer zoneNumber = nearest.getZoneNumber();
        double distanceMeters = nearest.getDistanceMeters();

        List<RestrictionWindow> zoneWindows = windows.stream()
                .filter(view -> Objects.equals(zoneNumber, view.getZoneNumber()))
                .filter(view -> view.getDayOfWeek() != null && view.getStartTime() != null && view.getEndTime() != null)
                .map(view -> new RestrictionWindow(
                        normalizeDayOfWeek(view.getDayOfWeek()),
                        view.getStartTime(),
                        view.getEndTime(),
                        view.getMaximumStayMinutes()
                ))
                .collect(Collectors.toList());

        if (zoneWindows.isEmpty()) {
            return Optional.empty();
        }

        for (RestrictionWindow window : zoneWindows) {
            ZonedDateTime occurrenceStart = occurrenceStartOnOrBefore(localStart, window);
            ZonedDateTime occurrenceEnd = occurrenceEndFromStart(occurrenceStart, window);
            if (!localStart.isBefore(occurrenceStart) && localStart.isBefore(occurrenceEnd)) {
                long minutesUntilEnd = Math.max(0, Duration.between(localStart, occurrenceEnd).toMinutes());
                Integer maxStay = window.maxStayMinutes();
                long allowedMinutes = minutesUntilEnd;
                if (maxStay != null && maxStay >= 0) {
                    allowedMinutes = Math.min(allowedMinutes, maxStay.longValue());
                }
                return Optional.of(new RestrictionDurationResult(
                        allowedMinutes,
                        RestrictionDurationResult.Scenario.ACTIVE_RESTRICTION,
                        maxStay,
                        zoneNumber,
                        distanceMeters,
                        occurrenceEnd,
                        null
                ));
            }
        }

        ZonedDateTime nextStart = null;
        RestrictionWindow nextWindow = null;

        for (RestrictionWindow window : zoneWindows) {
            ZonedDateTime candidate = nextOccurrenceStartAfter(localStart, window);
            if (nextStart == null || candidate.isBefore(nextStart)) {
                nextStart = candidate;
                nextWindow = window;
            }
        }

        if (nextStart == null) {
            return Optional.empty();
        }

        long minutesUntilNext = Math.max(0, Duration.between(localStart, nextStart).toMinutes());
        Integer nextMaxStay = nextWindow != null ? nextWindow.maxStayMinutes() : null;

        return Optional.of(new RestrictionDurationResult(
                minutesUntilNext,
                RestrictionDurationResult.Scenario.UNTIL_NEXT_RESTRICTION,
                nextMaxStay,
                zoneNumber,
                distanceMeters,
                null,
                nextStart
        ));
    }

    private ZonedDateTime occurrenceStartOnOrBefore(ZonedDateTime reference, RestrictionWindow window) {
        int referenceDow = reference.getDayOfWeek().getValue();
        int windowDow = window.dayOfWeek();
        int daysBack = (referenceDow - windowDow + 7) % 7;
        LocalDate occurrenceDate = reference.toLocalDate().minusDays(daysBack);
        return occurrenceDate.atTime(window.startTime()).atZone(MELBOURNE_ZONE);
    }

    private ZonedDateTime occurrenceEndFromStart(ZonedDateTime occurrenceStart, RestrictionWindow window) {
        LocalDate endDate = occurrenceStart.toLocalDate();
        ZonedDateTime end = endDate.atTime(window.endTime()).atZone(MELBOURNE_ZONE);
        if (!window.endTime().isAfter(window.startTime()) || !end.isAfter(occurrenceStart)) {
            end = end.plusDays(1);
        }
        return end;
    }

    private ZonedDateTime nextOccurrenceStartAfter(ZonedDateTime reference, RestrictionWindow window) {
        int referenceDow = reference.getDayOfWeek().getValue();
        int windowDow = window.dayOfWeek();
        int daysAhead = (windowDow - referenceDow + 7) % 7;
        LocalDate candidateDate = reference.toLocalDate().plusDays(daysAhead);
        ZonedDateTime candidate = candidateDate.atTime(window.startTime()).atZone(MELBOURNE_ZONE);
        if (!candidate.isAfter(reference)) {
            candidate = candidate.plusWeeks(1);
        }
        return candidate;
    }

    private int normalizeDayOfWeek(int dow) {
        if (dow < 1 || dow > 7) {
            throw new IllegalArgumentException("day_of_week outside ISO range 1-7: " + dow);
        }
        return dow;
    }

    private record RestrictionWindow(int dayOfWeek, LocalTime startTime, LocalTime endTime, Integer maxStayMinutes) { }
}

