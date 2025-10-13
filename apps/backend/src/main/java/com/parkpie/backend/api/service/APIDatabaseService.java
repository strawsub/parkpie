package com.parkpie.backend.api.service;

import com.google.gson.Gson;
import com.parkpie.backend.parking.repository.ParkingBayRealtimeRepository;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.sql.Time;

@Service
public class APIDatabaseService {

    private final JdbcTemplate jdbc;
    private final ParkingBayRealtimeRepository realtimeRepo;

    private static final double STREET_DESCRIPTION_MAX_DISTANCE_METERS = 100.0;

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
        double descriptionRadius = STREET_DESCRIPTION_MAX_DISTANCE_METERS;
        String sql = """
                SELECT 
                    ps.zone_number                AS id,
                    ST_Y(ps.location::geometry)   AS lat,
                    ST_X(ps.location::geometry)   AS lng,
                    ps.zone_number,
                    -- Get ONE occupancy per zone (not duplicated per restriction)
                    MAX(ps.occupancy_percent)     AS occupancy_percent,
                    MAX(ps.updated_at)            AS updated_at,
                    COALESCE(MAX(nb.description), 'N/A') AS description,
                    -- Aggregate all restrictions for this zone as JSON
                    JSON_AGG(
                        JSON_BUILD_OBJECT(
                            'day_of_week', ps.day_of_week,
                            'start_time', ps.start_time,
                            'end_time', ps.end_time,
                            'maximum_stay_minutes', ps.maximum_stay_minutes
                        ) ORDER BY ps.day_of_week, ps.start_time
                    ) AS restrictions
                FROM public.parking_signs ps
                LEFT JOIN LATERAL (
                        SELECT
                        pb.description,
                        pb.kerbside_id,
                        ST_Distance(ps.location::geography, pb.location::geography) AS distance_m
                        FROM public.parking_bays pb
                        WHERE ST_DWithin(
                            pb.location::geography,
                            ps.location::geography,
                            ?
                        )
                        ORDER BY ps.location <-> pb.location
                        LIMIT 1
                ) nb ON TRUE
                WHERE ps.zone_number IS NOT NULL
                GROUP BY ps.zone_number, ST_Y(ps.location::geometry), ST_X(ps.location::geometry)
                ORDER BY ps.zone_number;
                        """;
        
        allPin = jdbc.queryForList(sql, descriptionRadius);
        return allPin;
    }

    public List<Map<String, Object>> queryByPoint(double lat, double lng) {

        double radiusMeters = 100;

        String sql = """
            SELECT
                *,
                ST_Distance(
                    location::geography,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                ) AS distance
            FROM public.parking_signs
            WHERE ST_DWithin(
                location::geography,
                ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
                ?
            )
            ORDER BY distance ASC
            LIMIT 1
            """;

        List<Map<String, Object>> rows = jdbc.queryForList(sql, lng, lat, lng, lat, radiusMeters);
        return rows;
    }


    public List<Map<String, Object>> queryByFilter(
        double lat, double lng, double radius,
        Integer duration, String restrictionTime, String restrictionDate // time "HH:mm:ss", date "yyyy-MM-dd"
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
                    AND ps.day_of_week = ?
                """);

        LocalDate filterDate = LocalDate.now();
        if (restrictionDate != null && !restrictionDate.isBlank()) {
            try {
                filterDate = LocalDate.parse(restrictionDate);
            } catch (DateTimeParseException ignored) {
            }
        }
        int dowNo = filterDate.getDayOfWeek().getValue();

        List<Object> params = new ArrayList<>();
        // PostGIS: ST_MakePoint(lng, lat)
        params.add(lng); params.add(lat);
        params.add(lng); params.add(lat);
        params.add(radius);
        params.add(dowNo);

        if (duration != null) {
            sql.append(" AND (ps.maximum_stay_minutes IS NULL OR ps.maximum_stay_minutes = 0 OR ps.maximum_stay_minutes >= ?) ");
            params.add(duration);
        }

        if (restrictionTime != null && !restrictionTime.isBlank()) {
            sql.append("""
                AND (
                    ps.start_time IS NULL
                    OR ps.end_time IS NULL
                    OR (
                        (ps.end_time >= ps.start_time AND ?::time BETWEEN ps.start_time AND ps.end_time)
                        OR
                        (ps.end_time < ps.start_time AND (?::time >= ps.start_time OR ?::time <= ps.end_time))
                    )
                )
                """);
            params.add(restrictionTime);
            params.add(restrictionTime);
            params.add(restrictionTime);
        }

        sql.append(" ORDER BY distance ASC ");

        return jdbc.queryForList(sql.toString(), params.toArray());
    }


    public Map<String, Object> createParkingSession(double lat, double lng, String startTime) {
        try {
            List<Map<String, Object>> nearest = queryByPoint(lat, lng);
            if (nearest.isEmpty()) {
                return Map.of(
                    "created", false,
                    "reason", "NO_SIGN_FOUND"
                );
            }

            Map<String, Object> row = nearest.get(0);
            int signId = ((Number) row.get("id")).intValue();

            LocalTime lt = (startTime == null || startTime.isBlank())
                    ? LocalTime.now()
                    : LocalTime.parse(startTime); // expects "HH:mm:ss"

            String insertSql = """
                INSERT INTO public.parking_session (location, start_parking_time, parking_sign_id)
                VALUES (ST_SetSRID(ST_MakePoint(?, ?), 4326), ?, ?)
                RETURNING session_id
                """;

            Integer sessionId = jdbc.queryForObject(
                    insertSql,
                    Integer.class,
                    lng, lat,
                    Time.valueOf(lt),
                    signId
            );

            Map<String, Object> resp = new HashMap<>();
            resp.put("created", true);
            resp.put("session_id", sessionId);
            resp.put("parking_sign_id", signId);
            resp.put("lat", lat);
            resp.put("lng", lng);
            resp.put("start_time", lt.toString());
            return resp;

        } catch (Exception e) {
            // Log full stack trace for debugging
            e.printStackTrace();

            // Return a clean response to the client
            Map<String, Object> errorResp = new HashMap<>();
            errorResp.put("created", false);
            errorResp.put("reason", "DB_INSERT_FAILED");
            errorResp.put("error", e.getMessage());
            errorResp.put("lat", lat);
            errorResp.put("lng", lng);
            return errorResp;
        }
    }


    public Map<String, Object> deleteParkingSession(String sessionID) {
        Map<String, Object> resp = new HashMap<>();

        try {
            int id = Integer.parseInt(sessionID);

            String sql = "DELETE FROM public.parking_session WHERE session_id = ?";
            int rows = jdbc.update(sql, id);

            resp.put("deleted", rows > 0);
            resp.put("session_id", id);
            if (rows == 0) {
                resp.put("reason", "NOT_FOUND");
            }

        } catch (NumberFormatException nfe) {
            resp.put("deleted", false);
            resp.put("reason", "INVALID_ID");
            resp.put("session_id", sessionID);
        } catch (Exception e) {
            e.printStackTrace();
            resp.put("deleted", false);
            resp.put("reason", "DB_ERROR");
            resp.put("error", e.getMessage());
        }

        return resp;
    }


    public List<Map<String, Object>> getAllSegments() {

        String sql = """
            SELECT
                *
            FROM public.parking_segments
            """;

        List<Map<String, Object>> rows = jdbc.queryForList(sql);
        return rows;
    }

    // DEBUG: Get all parking signs to investigate database structure
    public List<Map<String, Object>> getAllRestrictionsForInvestigation() {
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
                nb.description,
                nb.kerbside_id
            FROM public.parking_signs ps
            LEFT JOIN LATERAL (
                SELECT
                pb.description,
                pb.kerbside_id
                FROM public.parking_bays pb
                ORDER BY ps.location <-> pb.location
                LIMIT 1
            ) nb ON TRUE
            ORDER BY ST_Y(ps.location::geometry), ST_X(ps.location::geometry), ps.day_of_week
            LIMIT 100
            """;

        return jdbc.queryForList(sql);
    }

    // DEBUG: Get all restrictions for a specific location across all days
    public List<Map<String, Object>> getAllRestrictionsForLocation(double lat, double lng, double radius) {
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
                nb.description,
                nb.kerbside_id,
                ST_Distance(
                    ps.location::geography,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                ) AS distance_m
            FROM public.parking_signs ps
            LEFT JOIN LATERAL (
                SELECT
                pb.description,
                pb.kerbside_id
                FROM public.parking_bays pb
                ORDER BY ps.location <-> pb.location
                LIMIT 1
            ) nb ON TRUE
            WHERE ST_DWithin(
                ps.location::geography,
                ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
                ?
            )
            ORDER BY distance_m ASC, ps.day_of_week ASC
            """;

        return jdbc.queryForList(sql, lng, lat, lng, lat, radius);
    }


    public List<Map<String, Object>> getLocationForSegment() {

        String sql_user_session = """
            SELECT
                ST_Y(ps.location::geometry) AS lat,
                ST_X(ps.location::geometry) AS lng
            FROM public.parking_session AS ps;
            """;

        List<Map<String, Object>> rows_us = jdbc.queryForList(sql_user_session);

        String sql_city_sensor = """
            SELECT
                ST_Y(pb.location::geometry) AS lat,
                ST_X(pb.location::geometry) AS lng
            FROM public.parking_bay_realtime pbr
            LEFT JOIN public.parking_bays pb
                ON pb.kerbside_id = pbr.kerbsideid
            WHERE pbr.status_description = 'Present'
            """;

        List<Map<String, Object>> rows_cs = jdbc.queryForList(sql_city_sensor);

        List<Map<String, Object>> merged = new ArrayList<>();
        merged.addAll(rows_us);
        merged.addAll(rows_cs);

        List<Map<String, Object>> features = loadGeoJson();

        Map<String, List<List<double[]>>> segmentRings = new LinkedHashMap<>();

        int fallbackIdx = 0;
        for (Map<String, Object> feature : features) {
            Map<String, Object> props = (Map<String, Object>) feature.get("properties");
            Map<String, Object> geom  = (Map<String, Object>) feature.get("geometry");
            if (geom == null) continue;

            String type = String.valueOf(geom.get("type"));
            String segId = firstNonNull(
                    asString(props, "seg_id"),
                    asString(props, "segment_id"),
                    asString(props, "id"),
                    "seg_" + (fallbackIdx++)
            );

            Object coordsObj = geom.get("coordinates");
            if (coordsObj == null) continue;

            List<List<double[]>> ringsForSeg = new ArrayList<>();

            if ("MultiPolygon".equalsIgnoreCase(type)) {
                List<Object> multi = (List<Object>) coordsObj;
                for (Object polyObj : multi) {
                    List<Object> polygon = (List<Object>) polyObj;
                    if (polygon.isEmpty()) continue;
                    // outer ring
                    List<Object> outer = (List<Object>) polygon.get(0);
                    ringsForSeg.add(toLngLatRing(outer));
                }
            } else if ("Polygon".equalsIgnoreCase(type)) {
                List<Object> polygon = (List<Object>) coordsObj;
                if (!polygon.isEmpty()) {
                    List<Object> outer = (List<Object>) polygon.get(0);
                    ringsForSeg.add(toLngLatRing(outer));
                }
            } else {
                continue;
            }

            if (!ringsForSeg.isEmpty()) {
                segmentRings.put(segId, ringsForSeg);
            }
        }

        Map<String, Integer> counts = new LinkedHashMap<>();
        for (Map<String, Object> row : merged) {
            Double lat = toDouble(row.get("lat"));
            Double lng = toDouble(row.get("lng"));
            if (lat == null || lng == null) continue;

            for (Map.Entry<String, List<List<double[]>>> e : segmentRings.entrySet()) {
                String segId = e.getKey();
                List<List<double[]>> rings = e.getValue();

                boolean insideAny = false;
                for (List<double[]> ring : rings) {
                    if (pointInPolygon(lng, lat, ring)) {
                        insideAny = true;
                        break;
                    }
                }
                if (insideAny) {
                    counts.merge(segId, 1, Integer::sum);
                    break;
                }
            }
        }

        List<Map<String, Object>> result = new ArrayList<>(counts.size());
        for (Map.Entry<String, Integer> e : counts.entrySet()) {
            Map<String, Object> m = new HashMap<>();
            m.put("seg_id", e.getKey());
            m.put("count", e.getValue());
            result.add(m);
        }
        return result;
    }


    public List<Map<String, Object>> loadGeoJson() {
        try {
            ClassPathResource resource = new ClassPathResource("assets/road_segment.geojson");
            InputStreamReader reader = new InputStreamReader(resource.getInputStream());

            Map<String, Object> geoJson = new Gson().fromJson(reader, Map.class);
            reader.close();

            List<Map<String, Object>> features = (List<Map<String, Object>>) geoJson.get("features");
            return features;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    private static String asString(Map<String, Object> m, String key) {
        if (m == null) return null;
        Object v = m.get(key);
        return (v == null) ? null : String.valueOf(v);
    }

    private static Double toDouble(Object o) {
        if (o == null) return null;
        if (o instanceof Number) return ((Number) o).doubleValue();
        try { return Double.parseDouble(o.toString()); } catch (Exception ignore) { return null; }
    }

    @SuppressWarnings("unchecked")
    private static List<double[]> toLngLatRing(List<Object> coords) {
        List<double[]> ring = new ArrayList<>(coords.size());
        for (Object ptObj : coords) {
            List<Object> pt = (List<Object>) ptObj;
            if (pt.size() < 2) continue;
            Double lng = toDouble(pt.get(0));
            Double lat = toDouble(pt.get(1));
            if (lng != null && lat != null) {
                ring.add(new double[]{lng, lat});
            }
        }
        return ring;
    }

    private static boolean pointInPolygon(double x, double y, List<double[]> ring) {
        boolean inside = false;
        int n = ring.size();
        if (n < 3) return false;

        for (int i = 0, j = n - 1; i < n; j = i++) {
            double xi = ring.get(i)[0], yi = ring.get(i)[1];
            double xj = ring.get(j)[0], yj = ring.get(j)[1];

            boolean intersect = ((yi > y) != (yj > y)) &&
                    (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
            if (intersect) inside = !inside;
        }
        return inside;
    }

    private static <T> T firstNonNull(T... vals) {
        for (T v : vals) if (v != null) return v;
        return null;
    }


    
}



