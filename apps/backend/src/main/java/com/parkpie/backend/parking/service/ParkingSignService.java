package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.dto.UserSignIngestDto;
import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Objects;
import java.util.stream.Collectors;

@Service
public class ParkingSignService {

    private static final double DUPLICATE_DETECTION_RADIUS_METERS = 15.0;

    private final ParkingSignRepository parkingSignRepository;

    public ParkingSignService(ParkingSignRepository parkingSignRepository) {
        this.parkingSignRepository = parkingSignRepository;
    }

    @Transactional(readOnly = true)
    public List<ParkingSignDto.SignView> findNear(double lat, double lng, double meters) {
        return parkingSignRepository.findNear(lat, lng, meters).stream()
                .map(nearView -> new ParkingSignDto.SignView(nearView.getId(), nearView.getText(), nearView.getLat(), nearView.getLng()))
                .toList();
    }

    @Transactional
    public UserSignIngestDto.Response ingestUserSign(UserSignIngestDto.Request req) {
        Objects.requireNonNull(req, "request");
        var location = Objects.requireNonNull(req.location, "location");
        double lat = Objects.requireNonNull(location.lat, "location.lat");
        double lng = Objects.requireNonNull(location.lng, "location.lng");

        if (req.restrictions == null || req.restrictions.isEmpty()) {
            throw new IllegalArgumentException("At least one restriction is required");
        }

        Map<String, UserSignIngestDto.Restriction> unique = new LinkedHashMap<>();
        for (var r : req.restrictions) {
            Integer dow = Objects.requireNonNull(r.day_of_week, "restriction.day_of_week");
            if (dow < 1 || dow > 7) {
                throw new IllegalArgumentException("day_of_week out of range: " + dow);
            }
            if (r.maximum_stay_minutes != null && r.maximum_stay_minutes < 0) {
                throw new IllegalArgumentException("maximum_stay_minutes must be >= 0 for day " + dow);
            }
            if (r.start_time == null || r.end_time == null) {
                throw new IllegalArgumentException("Missing start or end time for day " + dow);
            }
            String key = dow + "|" + r.start_time + "|" + r.end_time;
            unique.put(key, r);
        }

        Collection<UserSignIngestDto.Restriction> uniqueRestrictions = unique.values();

        int zoneNumber;
        int replaced = 0;
        if (req.zone_number != null) {
            zoneNumber = req.zone_number;
            if (zoneNumber >= 0) {
                throw new IllegalArgumentException("Manual zone_number must be negative");
            }
            replaced = parkingSignRepository.deleteByZone(zoneNumber);
        } else {
            Integer existingZone = findExistingManualZone(lat, lng, uniqueRestrictions);
            if (existingZone != null) {
                zoneNumber = existingZone;
                replaced = parkingSignRepository.deleteByZone(zoneNumber);
            } else {
                zoneNumber = allocateManualZoneNumber();
            }
        }

        LocalDateTime ingestTimestamp = LocalDateTime.now(ZoneOffset.UTC);
        int saved = 0;
        for (var r : uniqueRestrictions) {
            saved += parkingSignRepository.upsertManual(
                    zoneNumber,
                    lat,
                    lng,
                    r.day_of_week,
                    r.start_time,
                    r.end_time,
                    r.maximum_stay_minutes,
                    ingestTimestamp
            );
        }

        return new UserSignIngestDto.Response(zoneNumber, saved, replaced);
    }

    private int allocateManualZoneNumber() {
        long next = parkingSignRepository.nextManualZoneSequence();
        if (next <= 0) {
            throw new IllegalStateException("manual_zone_number_seq returned invalid value: " + next);
        }
        if (next > Integer.MAX_VALUE) {
            throw new IllegalStateException("manual zone number overflow");
        }
        return (int) -next;
    }

    private Integer findExistingManualZone(double lat, double lng, Collection<UserSignIngestDto.Restriction> restrictions) {
        var windows = parkingSignRepository.findRestrictionWindowsNear(lat, lng, DUPLICATE_DETECTION_RADIUS_METERS);
        if (windows.isEmpty()) {
            return null;
        }

        Map<Integer, List<ParkingSignRepository.RestrictionWindowView>> windowsByZone = windows.stream()
                .filter(view -> view.getZoneNumber() != null && view.getZoneNumber() < 0)
                .collect(Collectors.groupingBy(ParkingSignRepository.RestrictionWindowView::getZoneNumber));

        if (windowsByZone.isEmpty()) {
            return null;
        }

        Map<Integer, CandidateMatch> candidates = new HashMap<>();
        for (var entry : windowsByZone.entrySet()) {
            CandidateMatch candidate = new CandidateMatch(entry.getKey());
            entry.getValue().forEach(view -> candidate.updateDistance(view.getDistanceMeters()));
            candidates.put(entry.getKey(), candidate);
        }

        for (var restriction : restrictions) {
            for (var entry : windowsByZone.entrySet()) {
                boolean matches = entry.getValue().stream().anyMatch(view ->
                        Objects.equals(restriction.day_of_week, view.getDayOfWeek())
                                && Objects.equals(restriction.start_time, view.getStartTime())
                                && Objects.equals(restriction.end_time, view.getEndTime())
                                && Objects.equals(restriction.maximum_stay_minutes, view.getMaximumStayMinutes())
                );
                if (matches) {
                    candidates.get(entry.getKey()).incrementMatches();
                }
            }
        }

        return candidates.values().stream()
                .filter(candidate -> candidate.matchCount > 0)
                .sorted((a, b) -> {
                    int cmp = Integer.compare(b.matchCount, a.matchCount);
                    if (cmp != 0) {
                        return cmp;
                    }
                    return Double.compare(a.minDistanceMeters, b.minDistanceMeters);
                })
                .map(candidate -> candidate.zoneNumber)
                .findFirst()
                .orElse(null);
    }

    private static final class CandidateMatch {
        private final int zoneNumber;
        private double minDistanceMeters = Double.MAX_VALUE;
        private int matchCount = 0;

        private CandidateMatch(int zoneNumber) {
            this.zoneNumber = zoneNumber;
        }

        private void updateDistance(double distance) {
            if (distance < minDistanceMeters) {
                minDistanceMeters = distance;
            }
        }

        private void incrementMatches() {
            matchCount++;
        }
    }
}
