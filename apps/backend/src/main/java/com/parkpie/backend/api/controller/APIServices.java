package com.parkpie.backend.api.controller;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
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
}
