package com.parkpie.backend.core.controller;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HealthController {

    private final JdbcTemplate jdbc;

    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Integer one = jdbc.queryForObject("SELECT 1", Integer.class);
        String version = jdbc.queryForObject("SELECT version()", String.class);
        return Map.of("ok", one != null && one == 1, "dbVersion", version);
    }

    @GetMapping("/health/postgis")
    public Map<String, Object> postgis() {
        String wkt = jdbc.queryForObject(
                "SELECT ST_AsText(ST_GeomFromText('POINT(144.9631 -37.8136)', 4326))",
                String.class
        );
        return Map.of("point", wkt);
    }
}
