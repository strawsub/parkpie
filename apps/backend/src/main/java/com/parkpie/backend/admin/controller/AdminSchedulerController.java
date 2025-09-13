package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.SchedulerSettingsService;
import com.parkpie.backend.api.entity.AvailabilityFetchLog;
import com.parkpie.backend.api.repository.AvailabilityFetchLogRepository;
import com.parkpie.backend.api.service.AvailabilityJobRunner;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Controller
@RequestMapping("/admin/scheduler")
public class AdminSchedulerController {

    private final SchedulerSettingsService settings;
    private final AvailabilityJobRunner runner;
    private final AvailabilityFetchLogRepository logRepo;

    public AdminSchedulerController(SchedulerSettingsService settings,
                                    AvailabilityJobRunner runner,
                                    AvailabilityFetchLogRepository logRepo) {
        this.settings = settings;
        this.runner = runner;
        this.logRepo = logRepo;
    }

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

    @PostMapping
    public String update(@RequestParam(value = "enabled", required = false) String enabled,
                         @RequestParam("intervalMinutes") long intervalMinutes) {
        settings.setEnabled("on".equalsIgnoreCase(enabled) || "true".equalsIgnoreCase(enabled));
        settings.setIntervalMinutes(intervalMinutes);
        return "redirect:/admin/scheduler";
    }

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

    @GetMapping("/status")
    @ResponseBody
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

    @GetMapping("/logs")
    @ResponseBody
    public List<AvailabilityFetchLog> logs() {
        return logRepo.findTop50ByOrderByStartedAtDesc();
    }
}
