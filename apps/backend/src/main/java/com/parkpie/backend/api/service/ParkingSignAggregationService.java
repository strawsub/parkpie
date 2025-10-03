package com.parkpie.backend.api.service;

import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalTime;
import java.util.*;

@Service
public class ParkingSignAggregationService {

    private final JdbcTemplate jdbc;
    private final ParkingSignRepository signRepo;

    public ParkingSignAggregationService(JdbcTemplate jdbc, ParkingSignRepository signRepo) {
        this.jdbc = jdbc;
        this.signRepo = signRepo;
    }

    public record ZoneAgg(int bayCount, double lat, double lng, java.time.LocalDateTime updatedAt, Double occupancyPercent) {}

    // Key for identifying a restriction window row
    private static record WindowKey(Integer dayOfWeek, LocalTime startTime, LocalTime endTime) {}

    @Transactional
    public int rebuildFromRealtime() {
        List<Integer> zones = jdbc.query("SELECT DISTINCT zone_number FROM parking_bay_realtime WHERE zone_number IS NOT NULL ORDER BY zone_number",
                (rs, i) -> rs.getInt(1));
        int upserts = 0;
        for (Integer zone : zones) {
            ZoneAgg agg = aggregateZone(zone);
            if (agg == null) continue; // nothing to aggregate

            // Track the exact windows we (re)create this run for targeted cleanup
            Set<WindowKey> expected = new HashSet<>();
            Set<String> seen = new HashSet<>();
            List<Map<String, Object>> restrictions = fetchRestrictionsForZone(zone);
            restrictions = ensureSevenDays(restrictions);
            for (Map<String, Object> r : restrictions) {
                String key = keyOf(r);
                if (!seen.add(key)) continue;

                Integer dow = (Integer) r.get("day_of_week");
                LocalTime startT = (LocalTime) r.get("start_time");
                LocalTime endT = (LocalTime) r.get("end_time");
                Integer maxStay = (Integer) r.get("maximum_stay_minutes");

                // Skip any row with missing values
                if (dow == null || startT == null || endT == null ||
                        maxStay == null ||
                        agg.updatedAt() == null || agg.occupancyPercent() == null ||
                        Double.isNaN(agg.lat()) || Double.isNaN(agg.lng())) {
                    continue;
                }

                upserts += signRepo.upsertSign(
                        zone, agg.lat(), agg.lng(),
                        dow, startT, endT, maxStay,
                        agg.occupancyPercent(), agg.updatedAt()
                );
                expected.add(new WindowKey(dow, startT, endT));
            }

            // Delete only stale windows for this zone (do not count towards upsert total)
            deleteStaleWindows(zone, expected);
        }
        return upserts;
    }

    private String keyOf(Map<String, Object> r) {
        return r.get("day_of_week") + "|" + r.get("start_time") + "|" + r.get("end_time");
    }

    private ZoneAgg aggregateZone(int zone) {
        return jdbc.query("""
                SELECT COUNT(*) AS cnt,
                       AVG(pb.lat) AS avg_lat,
                       AVG(pb.lng) AS avg_lng,
                       MAX(r.lastupdated) AS max_last,
                       COUNT(*) FILTER (WHERE r.status_description = 'Present') AS present_cnt
                FROM parking_bay_realtime r
                JOIN parking_bays pb ON pb.kerbside_id = r.kerbsideid
                WHERE r.zone_number = ?
                """, ps -> ps.setInt(1, zone), (ResultSet rs) -> {
            if (!rs.next()) return null;
            int cnt = rs.getInt("cnt");
            if (cnt <= 0) return null;
            double lat = rs.getDouble("avg_lat");
            double lng = rs.getDouble("avg_lng");
            java.sql.Timestamp ts = rs.getTimestamp("max_last");
            java.time.LocalDateTime updatedAt = ts != null ? ts.toLocalDateTime() : null;
            int present = rs.getInt("present_cnt");
            Double occ = cnt > 0 ? (present * 1.0d) / cnt : null;
            return new ZoneAgg(cnt, lat, lng, updatedAt, occ);
        });
    }

    private List<Map<String, Object>> fetchRestrictionsForZone(int zone) {
        // Dominant zone code: by number of bays mapped via segments in this zone
        String dominant = jdbc.query(
                """
                SELECT l.pay_stay_zone
                FROM parking_bay_realtime r
                JOIN parking_bays pb ON pb.kerbside_id = r.kerbsideid
                JOIN pay_stay_zone_links l ON l.street_segment_id = pb.street_segment_id
                WHERE r.zone_number = ?
                GROUP BY l.pay_stay_zone
                ORDER BY COUNT(*) DESC
                LIMIT 1
                """,
                ps -> ps.setInt(1, zone), (rs, i) -> rs.getString(1)
        ).stream().findFirst().orElse(null);

        if (dominant == null || dominant.isBlank()) return List.of();

        String sql = """
                SELECT day_of_week, start_time, end_time,
                       maximum_stay_minutes
                FROM pay_stay_restrictions
                WHERE pay_stay_zone = ?
                ORDER BY day_of_week, start_time
                """;

        return jdbc.query(sql, ps -> ps.setString(1, dominant), (rs, i) -> mapRestriction(rs));
    }

    private Map<String, Object> mapRestriction(ResultSet rs) throws SQLException {
        Map<String, Object> m = new HashMap<>();
        m.put("day_of_week", rs.getInt("day_of_week"));
        m.put("start_time", rs.getObject("start_time", LocalTime.class));
        m.put("end_time", rs.getObject("end_time", LocalTime.class));
        m.put("maximum_stay_minutes", rs.getInt("maximum_stay_minutes"));
        return m;
    }

    /**
     * Ensure each zone has windows for days 1..7.
     * For any missing day d, copy all windows from the next available day after d (wraps to 1..7) and set day_of_week=d.
     */
    private List<Map<String, Object>> ensureSevenDays(List<Map<String, Object>> input) {
        if (input == null || input.isEmpty()) return input;
        Map<Integer, List<Map<String, Object>>> byDay = new HashMap<>();
        for (Map<String, Object> r : input) {
            Integer dow = (Integer) r.get("day_of_week");
            if (dow == null) continue;
            byDay.computeIfAbsent(dow, k -> new ArrayList<>()).add(r);
        }

        // if all 1..7 present, return as-is
        boolean all = true;
        for (int d = 1; d <= 7; d++) if (!byDay.containsKey(d)) { all = false; break; }
        if (all) return input;

        List<Map<String, Object>> out = new ArrayList<>(input);
        for (int d = 1; d <= 7; d++) {
            if (byDay.containsKey(d)) continue;
            // find next available day after d (wrap to 1)
            Integer src = null;
            for (int n = d + 1; n <= 7; n++) {
                if (byDay.containsKey(n)) { src = n; break; }
            }
            if (src == null) {
                for (int n = 1; n < d; n++) {
                    if (byDay.containsKey(n)) { src = n; break; }
                }
            }
            if (src == null) continue; // nothing to copy

            List<Map<String, Object>> srcRows = byDay.get(src);
            List<Map<String, Object>> clones = new ArrayList<>();
            for (Map<String, Object> r : srcRows) {
                Map<String, Object> copy = new HashMap<>(r);
                copy.put("day_of_week", d);
                clones.add(copy);
            }
            byDay.put(d, clones);
            out.addAll(clones);
        }
        return out;
    }

    private int deleteStaleWindows(int zone, Set<WindowKey> expectedWindows) {
        // If we didn't upsert any valid windows, remove all existing for this zone (matches prior behavior)
        if (expectedWindows == null || expectedWindows.isEmpty()) {
            return signRepo.deleteByZone(zone);
        }

        // Build a dynamic DELETE with tuple NOT IN (...) using JDBC parameters
        StringBuilder sql = new StringBuilder("DELETE FROM parking_signs WHERE zone_number = ? AND (day_of_week, start_time, end_time) NOT IN (");
        List<Object> params = new ArrayList<>();
        params.add(zone);

        int i = 0;
        for (WindowKey wk : expectedWindows) {
            if (i++ > 0) sql.append(", ");
            sql.append("(?, ?, ?)");
            params.add(wk.dayOfWeek());
            params.add(wk.startTime());
            params.add(wk.endTime());
        }
        sql.append(")");

        return jdbc.update(sql.toString(), params.toArray());
    }
}
