package com.parkpie.backend.admin.service;

import com.parkpie.backend.parking.repository.ParkingBayRepository;
import com.parkpie.backend.parking.repository.PayStayRestrictionRepository;
import com.parkpie.backend.parking.repository.PayStayZoneLinkRepository;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;

@Service
public class CsvImportService {

    private final ParkingBayRepository parkingBayRepository;
    private final PayStayZoneLinkRepository payStayZoneLinkRepository;
    private final PayStayRestrictionRepository payStayRestrictionRepository;

    public CsvImportService(
            ParkingBayRepository parkingBayRepository,
            PayStayZoneLinkRepository payStayZoneLinkRepository,
            PayStayRestrictionRepository payStayRestrictionRepository
    ) {
        this.parkingBayRepository = parkingBayRepository;
        this.payStayZoneLinkRepository = payStayZoneLinkRepository;
        this.payStayRestrictionRepository = payStayRestrictionRepository;
    }

    @Transactional
    public String importParkingBays(MultipartFile file) {
        int upserts = 0;

        try (var reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(
                     reader,
                     CSVFormat.DEFAULT.builder()
                             .setHeader("RoadSegmentID","KerbsideID","RoadSegmentDescription",
                                     "Latitude","Longitude","LastUpdated","Location")
                             .setSkipHeaderRecord(true)
                             .setIgnoreHeaderCase(true)
                             .setTrim(true)
                             .build()
             )) {

            for (CSVRecord r : parser) {
                String segIdStr = r.get("RoadSegmentID");
                if (segIdStr == null || segIdStr.isBlank()) continue;

                long streetSegmentId = Long.parseLong(segIdStr.trim());
                long kerbsideId = parseLongOrZero(nullIfBlank(r.get("KerbsideID"))); // missing -> 0
                String desc = nullIfBlank(r.get("RoadSegmentDescription"));

                double lat = round6(Double.parseDouble(r.get("Latitude")));
                double lng = round6(Double.parseDouble(r.get("Longitude")));
                LocalDate lastUpdated = parseFlexibleDate(r.get("LastUpdated"));

                // Geometry is created in SQL inside the repository UPSERT
                upserts += parkingBayRepository.upsertBay(
                        streetSegmentId, kerbsideId, desc, lat, lng, lastUpdated
                );
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Parking Bays: " + e.getMessage(), e);
        }
        return upserts + " rows upserted";
    }

    @Transactional
    public String importZoneLinks(MultipartFile file) {
        int upserts = 0;
        try (var reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(
                     reader,
                     CSVFormat.DEFAULT.builder()
                             .setHeader("pay_stay_zone","street","between_street_1","between_street_2","street_segment_id")
                             .setSkipHeaderRecord(true)
                             .setIgnoreHeaderCase(true)
                             .setTrim(true)
                             .build()
             )) {
            for (CSVRecord r : parser) {
                String zone = r.get("pay_stay_zone").trim();
                long segId = Long.parseLong(r.get("street_segment_id").trim());
                String street = nullIfBlank(r.get("street"));
                String b1 = nullIfBlank(r.get("between_street_1"));
                String b2 = nullIfBlank(r.get("between_street_2"));

                upserts += payStayZoneLinkRepository.upsertLink(zone, segId, street, b1, b2);
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Zone Links: " + e.getMessage(), e);
        }
        return upserts + " rows upserted";
    }

    @Transactional
    public String importRestrictions(MultipartFile file) {
        int upserts = 0;
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("H:mm"); // 7:30 or 07:30

        try (var reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(
                     reader,
                     CSVFormat.DEFAULT.builder()
                             .setHeader("pay_stay_zone","day_of_week","start_time","end_time",
                                     "minimum_stay","maximum_stay","cost_per_hour","day_of_week_name")
                             .setSkipHeaderRecord(true)
                             .setIgnoreHeaderCase(true)
                             .setTrim(true)
                             .build()
             )) {
            for (CSVRecord r : parser) {
                String zone = r.get("pay_stay_zone").trim();
                int dow = Integer.parseInt(r.get("day_of_week").trim());
                var startT = LocalTime.parse(r.get("start_time").trim(), timeFmt);
                var endT = LocalTime.parse(r.get("end_time").trim(), timeFmt);
                int minStay = Integer.parseInt(r.get("minimum_stay").trim());
                int maxStay = Integer.parseInt(r.get("maximum_stay").trim());
                int cents = Integer.parseInt(r.get("cost_per_hour").trim());
                String dowName = nullIfBlank(r.get("day_of_week_name"));

                upserts += payStayRestrictionRepository.upsertRestriction(
                        zone, dow, startT, endT, minStay, maxStay, cents, dowName
                );
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Restrictions: " + e.getMessage(), e);
        }
        return upserts + " rows upserted";
    }

    // ---------- helpers ----------
    private static long parseLongOrZero(String s) {
        if (s == null || s.isBlank()) return 0L;
        return Long.parseLong(s.trim());
    }

    private static String nullIfBlank(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }

    private static double round6(double v) {
        return Math.round(v * 1_000_000d) / 1_000_000d;
    }

    private static final java.time.format.DateTimeFormatter[] DATE_FORMATS = new java.time.format.DateTimeFormatter[]{
            java.time.format.DateTimeFormatter.ISO_LOCAL_DATE, // 2024-04-08
            java.time.format.DateTimeFormatter.ofPattern("d/M/uuuu"), // 8/4/2024
            java.time.format.DateTimeFormatter.ofPattern("dd/MM/uuuu"), // 08/04/2024
            java.time.format.DateTimeFormatter.ofPattern("M/d/uuuu"), // 4/8/2024 (US)
            java.time.format.DateTimeFormatter.ofPattern("d-MM-uuuu"), // 8-04-2024
            java.time.format.DateTimeFormatter.ofPattern("dd-MM-uuuu"), // 08-04-2024
            java.time.format.DateTimeFormatter.ofPattern("d MMM uuuu", Locale.ENGLISH) // 8 Apr 2024
    };

    private static LocalDate parseFlexibleDate(String raw) {
        if (raw == null) throw new DateTimeParseException("null", "", 0);
        String s = raw.trim();
        if (s.isEmpty()) throw new DateTimeParseException("empty", s, 0);
        for (java.time.format.DateTimeFormatter f : DATE_FORMATS) {
            try { return LocalDate.parse(s, f); } catch (DateTimeParseException ignored) {}
        }
        if (s.matches("\\d+(\\.\\d+)?")) { // Excel serial
            try {
                double v = Double.parseDouble(s);
                long days = (long)Math.floor(v);
                return LocalDate.of(1899, 12, 30).plusDays(days);
            } catch (Exception ignored) {}
        }
        return LocalDate.parse(s, java.time.format.DateTimeFormatter.ISO_LOCAL_DATE);
    }
}
