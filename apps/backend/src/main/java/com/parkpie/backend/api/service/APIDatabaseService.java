package com.parkpie.backend.api.service;

import com.parkpie.backend.parking.repository.ParkingBayRealtimeRepository;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class APIDatabaseService {

    private final JdbcTemplate jdbc;
    private final ParkingBayRealtimeRepository realtimeRepo;

    public APIDatabaseService(JdbcTemplate jdbc, ParkingBayRealtimeRepository realtimeRepo) {
        this.jdbc = jdbc;
        this.realtimeRepo = realtimeRepo;
    }

    private List<Map<String, Object>> rows = new ArrayList<>();

    public void downloadCSV() {
        rows = new ArrayList<>();

        String csvUrl = "https://data.melbourne.vic.gov.au/api/explore/v2.1/catalog/datasets/"
                + "on-street-parking-bay-sensors/exports/csv?lang=en&timezone=Australia%2FSydney"
                + "&use_labels=true&delimiter=%2C";

        try (InputStream input = new URL(csvUrl).openStream();
             InputStreamReader reader = new InputStreamReader(input, StandardCharsets.UTF_8);
             CSVParser parser = CSVParser.parse(reader, CSVFormat.DEFAULT.builder()
                     .setHeader("Lastupdated", "Status_Timestamp", "Zone_Number", "Status_Description", "KerbsideID", "Location")
                     .setSkipHeaderRecord(true)
                     .setIgnoreHeaderCase(true)
                     .setTrim(true)
                     .build())) {

            OffsetDateTime now = OffsetDateTime.now();
            for (CSVRecord r : parser) {
                String lastUpdatedStr = r.get("Lastupdated");
                String statusTsStr = r.get("Status_Timestamp");
                String statusDesc = r.get("Status_Description");
                String kerbStr = r.get("KerbsideID");
                String zoneStr = null;
                try { zoneStr = r.get("Zone_Number"); } catch (Exception ignored) {}

                if (lastUpdatedStr == null || statusTsStr == null || kerbStr == null || statusDesc == null) {
                    continue; // skip incomplete rows
                }

                OffsetDateTime lastUpdated = OffsetDateTime.parse(lastUpdatedStr.trim());
                if (Duration.between(lastUpdated, now).toMinutes() > 5) {
                    continue; // only keep very recent rows
                }

                Map<String, Object> row = new HashMap<>();
                row.put("kerbsideid", Integer.parseInt(kerbStr.trim()));
                row.put("lastupdated", lastUpdatedStr.trim());
                row.put("status_timestamp", statusTsStr.trim());
                row.put("status_description", statusDesc.trim());
                if (zoneStr != null && !zoneStr.isBlank()) {
                    try {
                        // Some feeds expose it as integer-like; tolerate decimals by parsing int part
                        int z = (int) Math.floor(Double.parseDouble(zoneStr.trim()));
                        row.put("zone_number", z);
                    } catch (NumberFormatException nfe) {
                        // leave absent
                    }
                }
                rows.add(row);
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to download/parse realtime CSV: " + e.getMessage(), e);
        }
    }

    public List<Map<String, Object>> getRows() {
        rows.sort(Comparator.comparingInt(r -> (Integer) r.get("kerbsideid")));
        return rows;
    }

    public void updateDatabase() {
        for (Map<String, Object> row : rows) {
            var lastUpdated = OffsetDateTime.parse((String) row.get("lastupdated")).toLocalDateTime();
            var statusTs = OffsetDateTime.parse((String) row.get("status_timestamp")).toLocalDateTime();
            var statusDesc = (String) row.get("status_description");
            var kerbsideId = ((Number) row.get("kerbsideid")).longValue();

            Integer zoneNumber = null;
            Object z = row.get("zone_number");
            if (z instanceof Number) zoneNumber = ((Number) z).intValue();

            realtimeRepo.upsert(kerbsideId, lastUpdated, statusTs, statusDesc, zoneNumber);
        }
    }

    // Get all signs from parking_signs table
    private List<Map<String, Object>> allPin = new ArrayList<>();

    public List<Map<String, Object>> getSignForPin() {

        // Get current date
        LocalDate today = LocalDate.now();

        // Get DayOfWeek (MONDAY=1, ... SUNDAY=7)
        DayOfWeek dow = today.getDayOfWeek();
        int dowNo = dow.getValue();

        String sql = """
                SELECT
                    ps.id,
                    ST_Y(ps.location::geometry) AS lat,
                    ST_X(ps.location::geometry) AS lng,
                    ps.day_of_week,
                    ps.occupancy_percent,
                    ps.start_time,
                    ps.end_time,
                    ps.maximum_stay_minutes,
                    ps.zone_number,
                    pr.zone_number,
                    pr.kerbsideid,
                    pb.kerbside_id,
                    pb.description
                FROM public.parking_signs AS ps
                LEFT JOIN parking_bay_realtime pr ON pr.zone_number=ps.zone_number
                LEFT JOIN parking_bays pb ON pb.kerbside_id=pr.kerbsideid
                WHERE ps.day_of_week = ?;
                        """;
        
        allPin = jdbc.queryForList(sql, dowNo);
        return allPin;
    }

    public List<Map<String, Object>> queryByPoint(double lat, double lng) {
        String sql = """
                SELECT
                    *,
                    ST_Distance(
                        location::geography,
                        ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                    ) AS distance
                FROM public.parking_signs
                ORDER BY distance ASC
                LIMIT 1
                """;
        return jdbc.queryForList(sql, lng, lat); 
    }


    public List<Map<String, Object>> queryByFilter(
        double lat, double lng, double radius,
        Integer duration, String restrictionTime // "HH:mm:ss"
    ) {
        StringBuilder sql = new StringBuilder("""
            SELECT
                ps.*,
                ST_Distance(
                    ps.location::geography,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                ) AS distance
            FROM public.parking_signs ps
            WHERE ST_DWithin(
                ps.location::geography,
                ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
                ?
            )
            """);

        List<Object> params = new ArrayList<>();
        // PostGIS: ST_MakePoint(lng, lat)
        params.add(lng); params.add(lat);
        params.add(lng); params.add(lat);
        params.add(radius);

        if (duration != null) {
            sql.append(" AND ps.maximum_stay_minutes >= ? ");
            params.add(duration);
        }

        if (restrictionTime != null && !restrictionTime.isBlank()) {
            // handle both normal windows and overnight windows (end < start)
            sql.append("""
                AND (
                    (ps.end_time >= ps.start_time AND ?::time BETWEEN ps.start_time AND ps.end_time)
                    OR
                    (ps.end_time < ps.start_time AND (?::time >= ps.start_time OR ?::time <= ps.end_time))
                )
                """);
            params.add(restrictionTime);
            params.add(restrictionTime);
            params.add(restrictionTime);
        }

        sql.append(" ORDER BY distance ASC ");

        return jdbc.queryForList(sql.toString(), params.toArray());
    }

}
