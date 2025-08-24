package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.AdminDatabaseService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class AdminPageController {

    private final AdminDatabaseService adminDatabaseService;

    public AdminPageController(AdminDatabaseService adminDatabaseService) {
        this.adminDatabaseService = adminDatabaseService;
    }

    @GetMapping("/admin")
    public String dashboard() {
        return "admin/dashboard";
    }

    @GetMapping("/admin/database")
    public String database(Model model) {
        model.addAttribute("database", adminDatabaseService.fetchDbInfo());
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/database";
    }

    @GetMapping("/admin/upload")
    public String upload() {
        return "admin/upload";
    }
}
