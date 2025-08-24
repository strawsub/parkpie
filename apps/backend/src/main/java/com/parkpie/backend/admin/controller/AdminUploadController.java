package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.CsvImportService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Controller
@RequestMapping("/admin/upload")
public class AdminUploadController {

    private final CsvImportService csvImportService;

    public AdminUploadController(CsvImportService csvImportService) {
        this.csvImportService = csvImportService;
    }

    @PostMapping("/bays")
    public String uploadBays(@RequestParam("file") MultipartFile file, Model model) {
        var summary = csvImportService.importParkingBays(file);
        model.addAttribute("message", "Imported Parking Bays: " + summary);
        return "admin/upload";
    }

    @PostMapping("/zone-links")
    public String uploadZoneLinks(@RequestParam("file") MultipartFile file, Model model) {
        var summary = csvImportService.importZoneLinks(file);
        model.addAttribute("message", "Imported Pay Stay Zone Links: " + summary);
        return "admin/upload";
    }

    @PostMapping("/restrictions")
    public String uploadRestrictions(@RequestParam("file") MultipartFile file, Model model) {
        var summary = csvImportService.importRestrictions(file);
        model.addAttribute("message", "Imported Pay Stay Restrictions: " + summary);
        return "admin/upload";
    }
}
