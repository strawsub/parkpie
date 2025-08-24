package com.parkpie.backend.admin.service;

import com.parkpie.backend.parking.entity.ParkingBay;
import com.parkpie.backend.parking.repository.ParkingBayRepository;
import com.parkpie.backend.parking.entity.PayStayRestriction;
import com.parkpie.backend.parking.entity.PayStayZoneLink;
import com.parkpie.backend.parking.repository.PayStayRestrictionRepository;
import com.parkpie.backend.parking.repository.PayStayZoneLinkRepository;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
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

    private final GeometryFactory geometryFactory;
    private final ParkingBayRepository parkingBayRepository;
    private final PayStayZoneLinkRepository payStayZoneLinkRepository;
    private final PayStayRestrictionRepository payStayRestrictionRepository;

    public CsvImportService(
            GeometryFactory geometryFactory,
            ParkingBayRepository parkingBayRepository,
            PayStayZoneLinkRepository payStayZoneLinkRepository,
            PayStayRestrictionRepository payStayRestrictionRepository
    ) {
        this.geometryFactory = geometryFactory;
        this.parkingBayRepository = parkingBayRepository;
        this.payStayZoneLinkRepository = payStayZoneLinkRepository;
        this.payStayRestrictionRepository = payStayRestrictionRepository;
    }

    @Transactional
    public String importParkingBays(MultipartFile file) {
        int created = 0;
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("d/MM/yyyy");

        try (var reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8);
             var parser = CSVParser.parse(
                     reader,
                     CSVFormat.DEFAULT.builder()
                             // Force our own header → avoids BOM/whitespace issues
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

                Long roadSegmentId = parseLong(segIdStr);
                Long kerbsideId = parseLong(nullIfBlank(r.get("KerbsideID")));
                String desc = nullIfBlank(r.get("RoadSegmentDescription"));
                double lat = Double.parseDouble(r.get("Latitude"));
                double lng = Double.parseDouble(r.get("Longitude"));
                LocalDate lastUpdated = parseFlexibleDate(r.get("LastUpdated"));

                Point p = geometryFactory.createPoint(new Coordinate(lng, lat));

                ParkingBay bay = new ParkingBay();
                bay.setRoadSegmentId(roadSegmentId);
                bay.setKerbsideId(kerbsideId);
                bay.setDescription(desc);
                bay.setLocation(p);
                bay.setLat(lat);
                bay.setLng(lng);
                bay.setLastUpdated(lastUpdated);
                parkingBayRepository.save(bay);
                created++;
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Parking Bays: " + e.getMessage(), e);
        }
        return created + " rows";
    }


    @Transactional
    public String importZoneLinks(MultipartFile file) {
        int created = 0;
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
                PayStayZoneLink z = new PayStayZoneLink();
                z.setPayStayZone(r.get("pay_stay_zone").trim());
                z.setStreet(r.get("street").trim());
                z.setBetweenStreet1(r.get("between_street_1").trim());
                z.setBetweenStreet2(r.get("between_street_2").trim());
                z.setStreetSegmentId(parseLong(r.get("street_segment_id")));
                payStayZoneLinkRepository.save(z);
                created++;
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Zone Links: " + e.getMessage(), e);
        }
        return created + " rows";
    }


    @Transactional
    public String importRestrictions(MultipartFile file) {
        int created = 0;
        DateTimeFormatter timeFmt = DateTimeFormatter.ofPattern("H:mm"); // accepts 7:30 and 07:30

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
                PayStayRestriction pr = new PayStayRestriction();
                pr.setPayStayZone(r.get("pay_stay_zone"));
                pr.setDayOfWeek(Integer.parseInt(r.get("day_of_week")));
                pr.setStartTime(LocalTime.parse(r.get("start_time"), timeFmt));
                pr.setEndTime(LocalTime.parse(r.get("end_time"), timeFmt));
                pr.setMinimumStayMinutes(Integer.parseInt(r.get("minimum_stay")));
                pr.setMaximumStayMinutes(Integer.parseInt(r.get("maximum_stay")));
                pr.setCostPerHourCents(Integer.parseInt(r.get("cost_per_hour")));
                pr.setDayOfWeekName(r.get("day_of_week_name"));
                payStayRestrictionRepository.save(pr);
                created++;
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to import Restrictions: " + e.getMessage(), e);
        }
        return created + " rows";
    }

    private static Long parseLong(String s) {
        if (s == null || s.isBlank()) return null;
        return Long.parseLong(s.trim());
    }

    private static String nullIfBlank(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }

    private static final DateTimeFormatter[] DATE_FORMATS = new DateTimeFormatter[]{
            DateTimeFormatter.ISO_LOCAL_DATE,                 // 2024-04-08
            DateTimeFormatter.ofPattern("d/M/uuuu"),          // 8/4/2024
            DateTimeFormatter.ofPattern("dd/MM/uuuu"),        // 08/04/2024
            DateTimeFormatter.ofPattern("M/d/uuuu"),          // 4/8/2024  (US)
            DateTimeFormatter.ofPattern("d-MM-uuuu"),         // 8-04-2024
            DateTimeFormatter.ofPattern("dd-MM-uuuu"),        // 08-04-2024
            DateTimeFormatter.ofPattern("d MMM uuuu", Locale.ENGLISH) // 8 Apr 2024
    };

    private static LocalDate parseFlexibleDate(String raw) {
        if (raw == null) throw new DateTimeParseException("null", "", 0);
        String s = raw.trim();
        if (s.isEmpty()) throw new DateTimeParseException("empty", s, 0);

        // Try listed patterns
        for (DateTimeFormatter f : DATE_FORMATS) {
            try { return LocalDate.parse(s, f); }
            catch (DateTimeParseException ignored) {}
        }

        // Excel numeric date (days since 1899-12-30)
        if (s.matches("\\d+(\\.\\d+)?")) {
            try {
                double v = Double.parseDouble(s);
                long days = (long)Math.floor(v);
                return LocalDate.of(1899, 12, 30).plusDays(days);
            } catch (Exception ignored) {}
        }

        // Last resort: let ISO try again to produce a clear error
        return LocalDate.parse(s, DateTimeFormatter.ISO_LOCAL_DATE);
    }
}
