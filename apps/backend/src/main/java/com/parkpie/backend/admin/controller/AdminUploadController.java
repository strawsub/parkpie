package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.CsvImportService;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequestMapping("/admin/upload")
public class AdminUploadController {

    private final CsvImportService csvImportService;

    public AdminUploadController(CsvImportService csvImportService) {
        this.csvImportService = csvImportService;
    }

    @PostMapping("/bays")
    public String uploadBays(@RequestParam("file") MultipartFile file, RedirectAttributes ra) {
        var summary = csvImportService.importParkingBays(file);
        ra.addFlashAttribute("message", "Imported Parking Bays: " + summary);
        return "redirect:/admin/upload";
    }

    @PostMapping("/zone-links")
    public String uploadZoneLinks(@RequestParam("file") MultipartFile file, RedirectAttributes ra) {
        var summary = csvImportService.importZoneLinks(file);
        ra.addFlashAttribute("message", "Imported Pay Stay Zone Links: " + summary);
        return "redirect:/admin/upload";
    }

    @PostMapping("/restrictions")
    public String uploadRestrictions(@RequestParam("file") MultipartFile file, RedirectAttributes ra) {
        var summary = csvImportService.importRestrictions(file);
        ra.addFlashAttribute("message", "Imported Pay Stay Restrictions: " + summary);
        return "redirect:/admin/upload";
    }
}
