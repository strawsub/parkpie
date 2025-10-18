package com.parkpie.backend.admin.controller;

import com.parkpie.backend.admin.service.CsvImportService;
import com.parkpie.backend.admin.service.UploadProgressService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Controller
@RequestMapping("/admin/upload")
@Tag(name = "Admin")
public class AdminUploadController {

    private final CsvImportService csvImportService;
    private final UploadProgressService uploadProgressService;

    public AdminUploadController(CsvImportService csvImportService,
                                 UploadProgressService uploadProgressService) {
        this.csvImportService = csvImportService;
        this.uploadProgressService = uploadProgressService;
    }

    @PostMapping("/bays")
    public String uploadBays(@RequestParam("file") MultipartFile file,
                             @RequestParam("progressId") String progressId,
                             RedirectAttributes ra) {
        try {
            uploadProgressService.createProgress(progressId);

            // IMPORTANT: read file now, before going async
            final byte[] bytes = file.getBytes();

            CompletableFuture.runAsync(() -> {
                try {
                    uploadProgressService.updateProgress(progressId, 1, "Validating file...", 25);
                    uploadProgressService.updateProgress(progressId, 2, "Parsing CSV data...", 50);
                    uploadProgressService.updateProgress(progressId, 3, "Processing data...", 75);

                    uploadProgressService.updateProgress(progressId, 4, "Saving to database...", 90);
                    String result = csvImportService.importParkingBays(bytes);
                    int count = Integer.parseInt(result.split(" ")[0]);
                    uploadProgressService.completeProgress(progressId, "Successfully imported " + count + " parking bays");
                } catch (Exception e) {
                    uploadProgressService.errorProgress(progressId, "Error: " + e.getMessage());
                }
            });

            ra.addFlashAttribute("message", "Upload started. Check progress below.");
            return "redirect:/admin/upload";
        } catch (Exception e) {
            ra.addFlashAttribute("error", "Upload failed: " + e.getMessage());
            return "redirect:/admin/upload";
        }
    }

    @PostMapping("/zone-links")
    public String uploadZoneLinks(@RequestParam("file") MultipartFile file,
                                  @RequestParam("progressId") String progressId,
                                  RedirectAttributes ra) {
        try {
            uploadProgressService.createProgress(progressId);
            final byte[] bytes = file.getBytes();

            CompletableFuture.runAsync(() -> {
                try {
                    uploadProgressService.updateProgress(progressId, 1, "Validating file...", 25);
                    uploadProgressService.updateProgress(progressId, 2, "Parsing CSV data...", 50);
                    uploadProgressService.updateProgress(progressId, 3, "Processing data...", 75);

                    uploadProgressService.updateProgress(progressId, 4, "Saving to database...", 90);
                    String result = csvImportService.importZoneLinks(bytes);
                    int count = Integer.parseInt(result.split(" ")[0]);
                    uploadProgressService.completeProgress(progressId, "Successfully imported " + count + " zone links");
                } catch (Exception e) {
                    uploadProgressService.errorProgress(progressId, "Error: " + e.getMessage());
                }
            });

            ra.addFlashAttribute("message", "Upload started. Check progress below.");
            return "redirect:/admin/upload";
        } catch (Exception e) {
            ra.addFlashAttribute("error", "Upload failed: " + e.getMessage());
            return "redirect:/admin/upload";
        }
    }

    @PostMapping("/restrictions")
    public String uploadRestrictions(@RequestParam("file") MultipartFile file,
                                     @RequestParam("progressId") String progressId,
                                     RedirectAttributes ra) {
        try {
            uploadProgressService.createProgress(progressId);
            final byte[] bytes = file.getBytes();

            CompletableFuture.runAsync(() -> {
                try {
                    uploadProgressService.updateProgress(progressId, 1, "Validating file...", 25);
                    uploadProgressService.updateProgress(progressId, 2, "Parsing CSV data...", 50);
                    uploadProgressService.updateProgress(progressId, 3, "Processing data...", 75);

                    uploadProgressService.updateProgress(progressId, 4, "Saving to database...", 90);
                    String result = csvImportService.importRestrictions(bytes);
                    int count = Integer.parseInt(result.split(" ")[0]);
                    uploadProgressService.completeProgress(progressId, "Successfully imported " + count + " restrictions");
                } catch (Exception e) {
                    uploadProgressService.errorProgress(progressId, "Error: " + e.getMessage());
                }
            });

            ra.addFlashAttribute("message", "Upload started. Check progress below.");
            return "redirect:/admin/upload";
        } catch (Exception e) {
            ra.addFlashAttribute("error", "Upload failed: " + e.getMessage());
            return "redirect:/admin/upload";
        }
    }

    @GetMapping("/progress/{progressId}")
    @ResponseBody
    @Operation(
            summary = "Fetch upload progress",
            description = "Returns the current status of a long-running admin upload task.",
            security = {@SecurityRequirement(name = "basicAuth")}
    )
    @ApiResponse(
            responseCode = "200",
            description = "Upload progress details.",
            content = @Content(
                    mediaType = "application/json",
                    schema = @Schema(example = "{\"id\":\"abc123\",\"currentStage\":3,\"totalStages\":4,\"status\":\"RUNNING\"}")
            )
    )
    public ResponseEntity<Map<String, Object>> getProgress(@PathVariable String progressId) {
        var p = uploadProgressService.getProgress(progressId);
        if (p == null) return ResponseEntity.notFound().build();

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("id", p.getId());
        body.put("currentStage", p.getCurrentStage());
        body.put("totalStages", p.getTotalStages());
        body.put("currentStageName", p.getCurrentStageName());
        body.put("progressPercentage", p.getProgressPercentage());
        body.put("status", p.getStatus());
        if (p.getMessage() != null && !p.getMessage().isBlank()) {
            body.put("message", p.getMessage());
        }
        return ResponseEntity.ok(body);
    }
}
