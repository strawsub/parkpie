package com.parkpie.backend.core.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Exposes health and connectivity probes that allow infrastructure to verify the availability of
 * the ParkPie backend and its PostGIS dependencies.
 */
@RestController
@Tag(name = "Health")
public class HealthController {

    private final JdbcTemplate jdbc;

    /**
     * Constructs the controller.
     *
     * @param jdbc template used to issue lightweight verification queries
     */
    public HealthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Performs a lightweight database round-trip and returns a JSON payload summarising application
     * status.
     *
     * @return map indicating whether the database is reachable and its reported version
     */
    @GetMapping("/health")
    @Operation(summary = "Application health probe", description = "Returns database connectivity and application liveness information.")
    @ApiResponse(
            responseCode = "200",
            description = "Application is healthy.",
            content = @Content(
                    mediaType = "application/json",
                    schema = @Schema(example = "{\"ok\": true, \"dbVersion\": \"PostgreSQL 16.2\"}")
            )
    )
    public Map<String, Object> health() {
        Integer one = jdbc.queryForObject("SELECT 1", Integer.class);
        String version = jdbc.queryForObject("SELECT version()", String.class);
        return Map.of("ok", one != null && one == 1, "dbVersion", version);
    }

    /**
     * Demonstrates that spatial extensions are operational by executing an inexpensive PostGIS
     * function.
     *
     * @return map containing the textual representation of a sample geometry
     */
    @GetMapping("/health/postgis")
    @Operation(summary = "PostGIS health probe", description = "Executes a simple PostGIS spatial query and returns the WKT representation.")
    @ApiResponse(
            responseCode = "200",
            description = "PostGIS spatial extensions are available.",
            content = @Content(
                    mediaType = "application/json",
                    schema = @Schema(example = "{\"point\": \"POINT (144.9631 -37.8136)\"}")
            )
    )
    public Map<String, Object> postgis() {
        String wkt = jdbc.queryForObject(
                "SELECT ST_AsText(ST_GeomFromText('POINT(144.9631 -37.8136)', 4326))",
                String.class
        );
        return Map.of("point", wkt);
    }
}
