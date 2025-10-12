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

import java.io.ByteArrayInputStream;
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
    private final ParkingSegmentBootstrapService parkingSegmentBootstrapService;

    public CsvImportService(ParkingBayRepository parkingBayRepository,
                            PayStayZoneLinkRepository payStayZoneLinkRepository,
                            PayStayRestrictionRepository payStayRestrictionRepository,
                            ParkingSegmentBootstrapService parkingSegmentBootstrapService) {
        this.parkingBayRepository = parkingBayRepository;
        this.payStayZoneLinkRepository = payStayZoneLinkRepository;
        this.payStayRestrictionRepository = payStayRestrictionRepository;
        this.parkingSegmentBootstrapService = parkingSegmentBootstrapService;
    }

    // Convenience overloads (safe if called synchronously)
    public String importParkingBays(MultipartFile file) {
        try {
            return importParkingBays(file.getBytes());
        } catch (Exception e) {
            throw new RuntimeException("Failed to read upload: " + e.getMessage(), e);
        }
    }

    public String importZoneLinks(MultipartFile file) {
        try {
            return importZoneLinks(file.getBytes());
        } catch (Exception e) {
            throw new RuntimeException("Failed to read upload: " + e.getMessage(), e);
        }
    }

    public String importRestrictions(MultipartFile file) {
        try {
            return importRestrictions(file.getBytes());
        } catch (Exception e) {
            throw new RuntimeException("Failed to read upload: " + e.getMessage(), e);
        }
    }

    // The async-safe versions the controller uses
    public String importParkingBays(byte[] bytes) {
        int upserts = 0;
        int skipped = 0;
        StringBuilder firstErrors = new StringBuilder();

        try (var reader = new InputStreamReader(new ByteArrayInputStream(bytes), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(reader, CSVFormat.DEFAULT.builder()
                     .setHeader("RoadSegmentID","KerbsideID","RoadSegmentDescription",
                             "Latitude","Longitude","LastUpdated","Location")
                     .setSkipHeaderRecord(true)
                     .setIgnoreHeaderCase(true)
                     .setTrim(true)
                     .build())) {

            for (CSVRecord r : parser) {
                try {
                    String segIdStr = r.get("RoadSegmentID");
                    if (segIdStr == null || segIdStr.isBlank()) {
                        skipped++; continue;
                    }

                    long streetSegmentId = Long.parseLong(segIdStr.trim());
                    Long kerbsideId = parseLongOrNull(nullIfBlank(r.get("KerbsideID")));
                    String desc = nullIfBlank(r.get("RoadSegmentDescription"));

                    String latRaw = r.get("Latitude");
                    String lngRaw = r.get("Longitude");
                    if (latRaw == null || lngRaw == null || latRaw.isBlank() || lngRaw.isBlank()) {
                        skipped++;
                        continue;
                    }
                    double lat = round6(Double.parseDouble(latRaw));
                    double lng = round6(Double.parseDouble(lngRaw));

                    LocalDate lastUpdated = parseFlexibleDateNullable(r.get("LastUpdated")); // nullable

                    if (kerbsideId != null && kerbsideId > 0) {
                        upserts += parkingBayRepository.upsertBay(
                                streetSegmentId, kerbsideId, desc, lat, lng, lastUpdated
                        );
                    } else {
                        int updated = parkingBayRepository.updateBayWithoutKerbside(streetSegmentId, desc, lat, lng, lastUpdated);
                        if (updated == 0) {
                            upserts += parkingBayRepository.insertBayWithoutKerbside(streetSegmentId, desc, lat, lng, lastUpdated);
                        } else {
                            upserts += updated;
                        }
                    }
                } catch (Exception rowEx) {
                    skipped++;
                    if (firstErrors.length() < 1000) {
                        firstErrors.append("Row ").append(r.getRecordNumber()).append(": ").append(rowEx.getMessage()).append("\n");
                    }
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Parking Bays: " + e.getMessage(), e);
        }

        String summary = upserts + " rows upserted, " + skipped + " rows skipped";
        if (firstErrors.length() > 0) {
            summary += " | sample errors:\n" + firstErrors;
        }
        return summary;
    }

    @Transactional
    public String importZoneLinks(byte[] bytes) {
        int upserts = 0;
        try (var reader = new InputStreamReader(new ByteArrayInputStream(bytes), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(reader, CSVFormat.DEFAULT.builder()
                     .setHeader("pay_stay_zone","street","between_street_1","between_street_2","street_segment_id")
                     .setSkipHeaderRecord(true).setIgnoreHeaderCase(true).setTrim(true).build())) {
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

    public String importRestrictions(byte[] bytes) {
        int upserts = 0;
        int skipped = 0;
        StringBuilder firstErrors = new StringBuilder();
        try (var reader = new InputStreamReader(new ByteArrayInputStream(bytes), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(reader, CSVFormat.DEFAULT.builder()
                     .setHeader("pay_stay_zone","day_of_week","start_time","end_time",
                             "minimum_stay","maximum_stay","cost_per_hour","day_of_week_name")
                     .setSkipHeaderRecord(true)
                     .setIgnoreHeaderCase(true)
                     .setTrim(true)
                     .build())) {
            for (CSVRecord r : parser) {
                try {
                    String zone = r.get("pay_stay_zone");
                    if (zone == null || zone.isBlank()) { skipped++; continue; }
                    zone = zone.trim();

                    String dowRaw = r.get("day_of_week");
                    if (dowRaw == null || dowRaw.isBlank()) { skipped++; continue; }
                    int dow = Integer.parseInt(dowRaw.trim());

                    LocalTime startT = parseFlexibleTime(r.get("start_time"));
                    LocalTime endT = parseFlexibleTime(r.get("end_time"));

                    Integer minStay = null;
                    String minStayRaw = r.get("minimum_stay");
                    if (minStayRaw != null && !minStayRaw.trim().isEmpty()) {
                        minStay = Integer.parseInt(minStayRaw.trim());
                    }
                    int maxStay = Integer.parseInt(r.get("maximum_stay").trim());
                    int cents = parseCents(r.get("cost_per_hour"));
                    String dowName = nullIfBlank(r.get("day_of_week_name"));

                    upserts += payStayRestrictionRepository.upsertRestriction(
                            zone, dow, startT, endT, minStay, maxStay, cents, dowName
                    );
                } catch (Exception rowEx) {
                    skipped++;
                    if (firstErrors.length() < 1000) {
                        firstErrors.append("Row ").append(r.getRecordNumber()).append(": ").append(rowEx.getMessage()).append("\n");
                    }
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Restrictions: " + e.getMessage(), e);
        }
        parkingSegmentBootstrapService.ensureStaticTables();
        String summary = upserts + " rows upserted, " + skipped + " rows skipped";
        if (firstErrors.length() > 0) {
            summary += " | sample errors:\n" + firstErrors;
        }
        return summary;
    }

    // ---- helpers ----
    private static LocalDate parseFlexibleDateNullable(String raw) {
        try { return parseFlexibleDate(raw); } catch (Exception ignored) { return null; }
    }

    private static Long parseLongOrNull(String s) {
        return (s == null || s.isBlank()) ? null : Long.parseLong(s.trim());
    }

    private static String nullIfBlank(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }

    private static double round6(double v) {
        return Math.round(v * 1_000_000d) / 1_000_000d;
    }

    private static final DateTimeFormatter[] DATE_FORMATS = new DateTimeFormatter[] {
            DateTimeFormatter.ISO_LOCAL_DATE,
            DateTimeFormatter.ofPattern("d/M/uuuu"),
            DateTimeFormatter.ofPattern("dd/MM/uuuu"),
            DateTimeFormatter.ofPattern("M/d/uuuu"),
            DateTimeFormatter.ofPattern("d-MM-uuuu"),
            DateTimeFormatter.ofPattern("dd-MM-uuuu"),
            DateTimeFormatter.ofPattern("d MMM uuuu", Locale.ENGLISH)
    };

    private static LocalDate parseFlexibleDate(String raw) {
        if (raw == null) throw new DateTimeParseException("null", "", 0);
        String s = raw.trim();
        if (s.isEmpty()) throw new DateTimeParseException("empty", s, 0);
        for (var f : DATE_FORMATS) {
            try { return LocalDate.parse(s, f); } catch (DateTimeParseException ignored) {}
        }
        if (s.matches("\\d+(\\.\\d+)?")) {
            double v = Double.parseDouble(s);
            long days = (long) Math.floor(v);
            return LocalDate.of(1899, 12, 30).plusDays(days);
        }
        return LocalDate.parse(s, DateTimeFormatter.ISO_LOCAL_DATE);
    }

    private static LocalTime parseFlexibleTime(String raw) {
        if (raw == null) throw new DateTimeParseException("null", "", 0);
        String s = raw.trim();
        if (s.isEmpty()) throw new DateTimeParseException("empty", s, 0);
        DateTimeFormatter[] fmts = new DateTimeFormatter[] {
                DateTimeFormatter.ofPattern("H:mm"),
                DateTimeFormatter.ofPattern("HH:mm"),
                DateTimeFormatter.ofPattern("H:mm:ss"),
                DateTimeFormatter.ofPattern("h:mm a", Locale.ENGLISH),
                DateTimeFormatter.ofPattern("h:mma", Locale.ENGLISH)
        };
        for (var f : fmts) {
            try { return LocalTime.parse(s, f); } catch (DateTimeParseException ignored) {}
        }
        // Convert 24:00 to 00:00 of next day by normalizing to 00:00
        if (s.equals("24:00") || s.equals("24:00:00")) {
            return LocalTime.MIDNIGHT;
        }
        // Last resort: let ISO parser try
        return LocalTime.parse(s);
    }

    private static int parseCents(String raw) {
        if (raw == null) return 0;
        String s = raw.trim();
        if (s.isEmpty()) return 0;
        // Remove currency symbols and spaces
        s = s.replace("$", "").replace(",", "");
        try {
            if (s.matches("^-?\\d+$")) {
                // already cents
                return Integer.parseInt(s);
            }
            // decimal dollars -> cents
            java.math.BigDecimal d = new java.math.BigDecimal(s);
            return d.movePointRight(2).setScale(0, java.math.RoundingMode.HALF_UP).intValueExact();
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid cost value: '" + raw + "'");
        }
    }
}
