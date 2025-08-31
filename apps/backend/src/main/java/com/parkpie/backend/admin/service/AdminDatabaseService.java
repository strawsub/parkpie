package com.parkpie.backend.admin.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.HashMap;
import java.util.Map;

@Service
public class AdminDatabaseService {

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;

    public AdminDatabaseService(JdbcTemplate jdbc, DataSource dataSource) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
    }

    public Map<String, Object> fetchDbInfo() {
        Map<String, Object> m = new HashMap<>();
        String version = jdbc.queryForObject("SELECT version()", String.class);
        String database = jdbc.queryForObject("SELECT current_database()", String.class);
        String postgis = null;
        try {
            postgis = jdbc.queryForObject("SELECT PostGIS_Full_Version()", String.class);
        } catch (Exception ignored) {} // TBD log.warn("Failed to query PostGIS version", e);

        m.put("version", version);
        m.put("database", database);
        m.put("postgis", postgis);

        try (Connection c = dataSource.getConnection()) {
            m.put("url", c.getMetaData().getURL());
            m.put("user", c.getMetaData().getUserName());
        } catch (Exception e) {
            m.put("url", "(unknown)");
            m.put("user", "(unknown)");
        }
        return m;
    }

    public Map<String, Object> fetchTableCounts() {
        Map<String, Object> c = new HashMap<>();
        c.put("parking_signs", safeCount("parking_signs"));
        c.put("parking_bays", safeCount("parking_bays"));
        c.put("pay_stay_zone_links", safeCount("pay_stay_zone_links"));
        c.put("pay_stay_restrictions", safeCount("pay_stay_restrictions"));
        return c;
    }

    private long safeCount(String table) {
        try {
            Long n = jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Long.class);
            return n == null ? 0L : n;
        } catch (Exception e) {
            return 0L;// TBD
        }
    }
}
