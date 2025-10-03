package com.parkpie.backend.api.controller;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.parkpie.backend.api.service.APIDatabaseService;
import com.parkpie.backend.api.service.AvailabilityJobRunner;

@Controller
public class APIServices {
    private final APIDatabaseService dbService;
    private final AvailabilityJobRunner runner;

    public APIServices(APIDatabaseService dbService, AvailabilityJobRunner runner) {
        this.dbService = dbService;
        this.runner = runner;
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
}

