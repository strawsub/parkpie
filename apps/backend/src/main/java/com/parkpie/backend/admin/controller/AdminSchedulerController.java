package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.SchedulerSettingsService;
import com.parkpie.backend.api.service.AvailabilityJobRunner;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Controller
@RequestMapping("/admin/scheduler")
public class AdminSchedulerController {

    private final SchedulerSettingsService settings;
    private final AvailabilityJobRunner runner;

    public AdminSchedulerController(SchedulerSettingsService settings, AvailabilityJobRunner runner) {
        this.settings = settings;
        this.runner = runner;
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
            String status = runner.runOnce();
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
        Instant s = settings.getLastRunStart();
        Instant e = settings.getLastRunEnd();
        m.put("lastRunStart", s != null ? s.toString() : null);
        m.put("lastRunEnd", e != null ? e.toString() : null);
        m.put("lastStatus", settings.getLastStatus());
        m.put("lastError", settings.getLastError());
        m.put("runCount", settings.getRunCount());
        return ResponseEntity.ok(m);
    }
}

