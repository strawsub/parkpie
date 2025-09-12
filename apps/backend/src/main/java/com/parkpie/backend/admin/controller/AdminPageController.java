package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.AdminDatabaseService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.HashMap;
import java.util.Map;

@Controller
public class AdminPageController {

    private final AdminDatabaseService adminDatabaseService;

    public AdminPageController(AdminDatabaseService adminDatabaseService) {
        this.adminDatabaseService = adminDatabaseService;
    }

    @GetMapping("/admin")
    public String dashboard(Model model) {
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/dashboard";
    }

    @GetMapping("/admin/database")
    public String database(Model model) {
        model.addAttribute("database", adminDatabaseService.fetchDbInfo());
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/database";
    }

    @GetMapping("/admin/upload")
    public String upload(Model model) {
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/upload";
    }
    
    @GetMapping("/admin/health")
    @ResponseBody
    public Map<String, Object> health() {
        Map<String, Object> health = new HashMap<>();
        try {
            Map<String, Object> dbInfo = adminDatabaseService.fetchDbInfo();
            health.put("status", "UP");
            health.put("database", "UP");
            health.put("timestamp", System.currentTimeMillis());
            health.put("version", "1.0.0");
        } catch (Exception e) {
            health.put("status", "DOWN");
            health.put("database", "DOWN");
            health.put("error", e.getMessage());
        }
        return health;
    }
}
