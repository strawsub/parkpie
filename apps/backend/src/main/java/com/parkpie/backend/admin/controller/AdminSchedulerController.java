package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.SchedulerSettingsService;
import com.parkpie.backend.api.entity.AvailabilityFetchLog;
import com.parkpie.backend.api.repository.AvailabilityFetchLogRepository;
import com.parkpie.backend.api.service.AvailabilityJobRunner;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Serves the administrative scheduler UI and JSON helpers that expose job status. Operators use
 * these endpoints to configure and monitor the availability fetch job.
 */
@Controller
@RequestMapping("/admin/scheduler")
@Tag(name = "Admin")
public class AdminSchedulerController {

    private final SchedulerSettingsService settings;
    private final AvailabilityJobRunner runner;
    private final AvailabilityFetchLogRepository logRepo;

    /**
     * Creates the controller.
     *
     * @param settings scheduler configuration service
     * @param runner   job runner used to trigger immediate executions
     * @param logRepo  repository providing recent execution logs
     */
    public AdminSchedulerController(SchedulerSettingsService settings,
                                    AvailabilityJobRunner runner,
                                    AvailabilityFetchLogRepository logRepo) {
        this.settings = settings;
        this.runner = runner;
        this.logRepo = logRepo;
    }

    /**
     * Renders the scheduler overview page with configuration and recent logs.
     *
     * @param model MVC model loaded with scheduler attributes
     * @return template name for the scheduler dashboard
     */
    @GetMapping
    public String scheduler(Model model) {
        model.addAttribute("enabled", settings.isEnabled());
        model.addAttribute("intervalMinutes", settings.getIntervalMinutes());
        model.addAttribute("running", settings.isRunning());
        model.addAttribute("lastRunStart", settings.getLastRunStart());
        model.addAttribute("lastRunEnd", settings.getLastRunEnd());
        model.addAttribute("lastStatus", settings.getLastStatus());
        model.addAttribute("lastError", settings.getLastError());
        model.addAttribute("runCount", settings.getRunCount());
        model.addAttribute("logs", logRepo.findTop50ByOrderByStartedAtDesc());
        return "admin/scheduler";
    }

    /**
     * Updates scheduler configuration submitted from the UI.
     *
     * @param enabled        string flag derived from checkbox input
     * @param intervalMinutes new execution interval in minutes
     * @return redirect back to the scheduler page
     */
    @PostMapping
    public String update(@RequestParam(value = "enabled", required = false) String enabled,
                         @RequestParam("intervalMinutes") long intervalMinutes) {
        settings.setEnabled("on".equalsIgnoreCase(enabled) || "true".equalsIgnoreCase(enabled));
        settings.setIntervalMinutes(intervalMinutes);
        return "redirect:/admin/scheduler";
    }

    /**
     * Triggers a manual availability fetch if the scheduler is idle.
     *
     * @return redirect back to the scheduler page
     */
    @PostMapping("/trigger")
    public String trigger() {
        if (settings.isRunning()) {
            return "redirect:/admin/scheduler";
        }
        if (!settings.markRunning()) {
            return "redirect:/admin/scheduler";
        }
        try {
            settings.setEnabled(settings.isEnabled()); // no-op to keep state
            settings.markStart();
            String status = runner.runOnce("manual");
            settings.markEndSuccess(status);
        } catch (Exception e) {
            settings.markEndError(e.getMessage());
        } finally {
            settings.markFinished();
        }
        return "redirect:/admin/scheduler";
    }

    /**
     * Returns the most recent scheduler status snapshot.
     *
     * @return JSON response describing scheduler configuration and last execution
     */
    @GetMapping("/status")
    @ResponseBody
    @Operation(
            summary = "Scheduler status snapshot",
            description = "Provides the latest information about the availability fetch scheduler.",
            security = {@SecurityRequirement(name = "basicAuth")}
    )
    @ApiResponse(
            responseCode = "200",
            description = "Current scheduler status.",
            content = @Content(
                    mediaType = "application/json",
                    schema = @Schema(example = "{\"enabled\":true,\"intervalMinutes\":15,\"running\":false}")
            )
    )
    public ResponseEntity<Map<String, Object>> status() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("enabled", settings.isEnabled());
        m.put("intervalMinutes", settings.getIntervalMinutes());
        m.put("running", settings.isRunning());
        LocalDateTime s = settings.getLastRunStart();
        LocalDateTime e = settings.getLastRunEnd();
        m.put("lastRunStart", s);
        m.put("lastRunEnd", e);
        m.put("lastStatus", settings.getLastStatus());
        m.put("lastError", settings.getLastError());
        m.put("runCount", settings.getRunCount());
        return ResponseEntity.ok(m);
    }

    /**
     * Provides the most recent scheduler execution logs as JSON.
     *
     * @return list of the last fifty availability fetch executions
     */
    @GetMapping("/logs")
    @ResponseBody
    @Operation(
            summary = "Recent scheduler runs",
            description = "Returns the 50 most recent availability fetch executions.",
            security = {@SecurityRequirement(name = "basicAuth")}
    )
    @ApiResponse(
            responseCode = "200",
            description = "Recent scheduler executions.",
            content = @Content(
                    mediaType = "application/json",
                    array = @ArraySchema(schema = @Schema(implementation = AvailabilityFetchLog.class))
            )
    )
    public List<AvailabilityFetchLog> logs() {
        return logRepo.findTop50ByOrderByStartedAtDesc();
    }
}
