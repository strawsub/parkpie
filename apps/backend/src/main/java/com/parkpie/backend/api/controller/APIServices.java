package com.parkpie.backend.api.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import com.parkpie.backend.api.service.APIDatabaseService;

@Controller
public class APIServices {
    private final APIDatabaseService dbService;

    public APIServices(APIDatabaseService dbService) {
        this.dbService = dbService;
    }

    @GetMapping("/api/updateavailability")
    public String landing(Model model) {
        dbService.downloadCSV();
        model.addAttribute("dataList", dbService.getRows());
        dbService.updateDatabase();
        return "api/landing";
    }
}
