package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.AdminDatabaseService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.HashMap;
import java.util.Map;

/**
 * Serves administrative HTML pages and supporting JSON helpers used by operations staff.
 */
@Controller
@Tag(name = "Admin")
public class AdminPageController {

    private final AdminDatabaseService adminDatabaseService;

    /**
     * Creates the controller.
     *
     * @param adminDatabaseService service that exposes aggregated database metadata
     */
    public AdminPageController(AdminDatabaseService adminDatabaseService) {
        this.adminDatabaseService = adminDatabaseService;
    }

    /**
     * Renders the administrative dashboard page.
     *
     * @param model MVC model populated with table counts
     * @return dashboard template name
     */
    @GetMapping("/admin")
    public String dashboard(Model model) {
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/dashboard";
    }

    /**
     * Renders the database overview page summarising table information.
     *
     * @param model MVC model enriched with database metadata
     * @return database template name
     */
    @GetMapping("/admin/database")
    public String database(Model model) {
        model.addAttribute("database", adminDatabaseService.fetchDbInfo());
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/database";
    }

    /**
     * Renders the CSV upload management page.
     *
     * @param model MVC model populated with record counts
     * @return upload template name
     */
    @GetMapping("/admin/upload")
    public String upload(Model model) {
        model.addAttribute("counts", adminDatabaseService.fetchTableCounts());
        return "admin/upload";
    }
    
    /**
     * Reports a lightweight health status tailored for the administration experience.
     *
     * @return map describing current availability of admin dependencies
     */
    @GetMapping("/admin/health")
    @ResponseBody
    @Operation(
            summary = "Admin UI health",
            description = "Returns the status of dependencies used by the administrative console.",
            security = {@SecurityRequirement(name = "basicAuth")}
    )
    @ApiResponse(
            responseCode = "200",
            description = "Health report for the admin console.",
            content = @Content(
                    mediaType = "application/json",
                    schema = @Schema(example = "{\"status\":\"UP\",\"database\":\"UP\",\"version\":\"1.0.0\"}")
            )
    )
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
