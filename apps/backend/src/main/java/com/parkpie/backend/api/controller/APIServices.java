package com.parkpie.backend.api.controller;

import com.parkpie.backend.api.dto.RestrictionDurationApiResponse;
import com.parkpie.backend.api.service.APIDatabaseService;
import com.parkpie.backend.api.service.AvailabilityJobRunner;
import com.parkpie.backend.parking.dto.RestrictionDurationResult;
import com.parkpie.backend.parking.service.ParkingRestrictionDurationService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Controller
public class APIServices {
    private static final ZoneId DEFAULT_ZONE = ParkingRestrictionDurationService.MELBOURNE_ZONE;

    private final APIDatabaseService dbService;
    private final AvailabilityJobRunner runner;
    private final ParkingRestrictionDurationService restrictionDurationService;

    public APIServices(
            APIDatabaseService dbService,
            AvailabilityJobRunner runner,
            ParkingRestrictionDurationService restrictionDurationService
    ) {
        this.dbService = dbService;
        this.runner = runner;
        this.restrictionDurationService = restrictionDurationService;
    }

    @GetMapping("/api/updateavailability")
    public String landingUpdateAvailability(Model model) {
        String status = runner.runOnce("api");
        model.addAttribute("status", status);
        return "api/landing";
    }

    @ResponseBody
    @GetMapping("/api/map/getsignforpin")
    public List<Map<String, Object>> getLocForPin() {
        return dbService.getSignForPin();
    }


    // Lat, Long -> Nearby Parking Bays
    @ResponseBody
    @GetMapping("/api/map/querybylocation")
    public List<Map<String, Object>> queryByLocation(
            @RequestParam("lat") double lat,
            @RequestParam("lng") double lng) {
        return dbService.queryByPoint(lat, lng); 
    }

    @ResponseBody
    @GetMapping("/api/map/querybyradius")
    public List<Map<String, Object>> queryByRadius(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam double radius,
            @RequestParam(required = false) Integer duration,
            @RequestParam(required = false) String restrictionTime,
            @RequestParam(required = false) String restrictionDate
    ) {
        return dbService.queryByFilter(lat, lng, radius, duration, restrictionTime, restrictionDate);
    }

    @ResponseBody
    @GetMapping("/api/map/createsession")
    public Map<String, Object> createSessionViaGet(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(required = false) String startTime
    ) {
        return dbService.createParkingSession(lat, lng, startTime);
    }


    @ResponseBody
    @GetMapping("/api/map/deletesession")
    public Map<String, Object> deleteSessionViaGet(
        @RequestParam String sessionID
    ){
        return dbService.deleteParkingSession(sessionID);
    }


    @ResponseBody
    @GetMapping("/api/map/getallsegments")
    public List<Map<String, Object>> getAllSegments() {
        return dbService.getAllSegments();
    }

    // TODO: Remove these debug endpoints after API enhancement is complete
    // DEBUG: Temporary endpoint to investigate database structure
    @ResponseBody
    @GetMapping("/api/debug/getallrestrictions")
    public List<Map<String, Object>> getAllRestrictionsDebug() {
        return dbService.getAllRestrictionsForInvestigation();
    }

    // DEBUG: Get all restrictions for a specific location
    @ResponseBody
    @GetMapping("/api/debug/getlocationrestrictions")
    public List<Map<String, Object>> getLocationRestrictionsDebug(
            @RequestParam("lat") double lat,
            @RequestParam("lng") double lng,
            @RequestParam(defaultValue = "100") double radius) {
        return dbService.getAllRestrictionsForLocation(lat, lng, radius);
    }

    @ResponseBody
    @GetMapping("/api/map/restrictionduration")
    public RestrictionDurationApiResponse getRestrictionDuration(
            @RequestParam("lat") double lat,
            @RequestParam("lng") double lng,
            @RequestParam("startTime") String startTimeRaw,
            @RequestParam(value = "zone", required = false) Integer zoneNumber
    ) {
        if (zoneNumber != null && zoneNumber >= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "zone must be a negative manual zone id");
        }
        OffsetDateTime startTime = parseStartTime(startTimeRaw);
        Optional<RestrictionDurationResult> result = restrictionDurationService.calculateDuration(lat, lng, startTime, zoneNumber);
        if (result.isEmpty()) {
            if (zoneNumber != null) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No matching restrictions for supplied zone or nearby location");
            }
            return null;
        }
        return toApiResponse(result.get());
    }

    @ResponseBody
    @GetMapping("/api/segment/getlocationforsegment")
    public List<Map<String, Object>> getLocationForSegment()
           {
        return dbService.getLocationForSegment();
    }

    private RestrictionDurationApiResponse toApiResponse(RestrictionDurationResult result) {
        return new RestrictionDurationApiResponse(
                result.durationMinutes(),
                result.scenario().name(),
                result.maxStayMinutes(),
                result.zoneNumber(),
                result.distanceMeters(),
                result.restrictionWindowEnd() != null ? result.restrictionWindowEnd().toOffsetDateTime() : null,
                result.nextRestrictionStart() != null ? result.nextRestrictionStart().toOffsetDateTime() : null,
                result.matchedByZoneId()
        );
    }

    private OffsetDateTime parseStartTime(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "startTime is required");
        }
        try {
            return OffsetDateTime.parse(raw);
        } catch (DateTimeParseException first) {
            try {
                return LocalDateTime.parse(raw).atZone(DEFAULT_ZONE).toOffsetDateTime();
            } catch (DateTimeParseException second) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Invalid startTime format. Use ISO-8601, e.g. 2025-10-10T15:00:00+10:00",
                        second
                );
            }
        }
    }
}
