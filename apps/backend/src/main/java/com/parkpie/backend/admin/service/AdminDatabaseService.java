package com.parkpie.backend.admin.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.HashMap;
import java.util.Map;

/**
 * Provides database metadata and statistics used by the administrative UI.
 */
@Service
public class AdminDatabaseService {

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;

    /**
     * Creates the service.
     *
     * @param jdbc JDBC template used for quick metadata queries
     * @param dataSource backing data source used to resolve connection metadata
     */
    public AdminDatabaseService(JdbcTemplate jdbc, DataSource dataSource) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
    }

    /**
     * Fetches database metadata such as version, current database, PostGIS status, and connection
     * details.
     *
     * @return map of database metadata values
     */
    public Map<String, Object> fetchDbInfo() {
        Map<String, Object> m = new HashMap<>();
        String version = jdbc.queryForObject("SELECT version()", String.class);
        String database = jdbc.queryForObject("SELECT current_database()", String.class);
        String postgis = null;
        try {
            postgis = jdbc.queryForObject("SELECT PostGIS_Full_Version()", String.class);
        } catch (Exception ignored) {}

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

    /**
     * Retrieves table counts for key domain tables used by the admin dashboards.
     *
     * @return map of table names to row counts
     */
    public Map<String, Object> fetchTableCounts() {
        Map<String, Object> c = new HashMap<>();
        c.put("parking_signs", safeCount("parking_signs"));
        c.put("parking_bays", safeCount("parking_bays"));
        c.put("pay_stay_zone_links", safeCount("pay_stay_zone_links"));
        c.put("pay_stay_restrictions", safeCount("pay_stay_restrictions"));
        c.put("parking_bay_realtime", safeCount("parking_bay_realtime"));
        return c;
    }

    /**
     * Executes a defensive count query that suppresses exceptions.
     *
     * @param table table name to count
     * @return number of rows or zero when unavailable
     */
    private long safeCount(String table) {
        try {
            Long n = jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Long.class);
            return n == null ? 0L : n;
        } catch (Exception e) {
            return 0L;
        }
    }
}
