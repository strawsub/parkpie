package com.parkpie.backend.api.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class APIDatabaseService {

    private final JdbcTemplate jdbc;

    public APIDatabaseService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private List<Map<String, Object>> rows = new ArrayList<>();

    public void downloadCSV() {
        rows = new ArrayList<>();

        String csvUrl = "https://data.melbourne.vic.gov.au/api/explore/v2.1/catalog/datasets/"
                + "on-street-parking-bay-sensors/exports/csv?lang=en&timezone=Australia%2FSydney"
                + "&use_labels=true&delimiter=%2C";

        try (
                InputStream input = new URL(csvUrl).openStream();
                InputStreamReader reader = new InputStreamReader(input, StandardCharsets.UTF_8);
                BufferedReader br = new BufferedReader(reader)
        ) {
            String header = br.readLine();
            String line;

            while ((line = br.readLine()) != null) {
                String[] parts = line.split(",", -1);

                OffsetDateTime lastUpdated = OffsetDateTime.parse(parts[0]);
                OffsetDateTime now = OffsetDateTime.now();

                if (Duration.between(lastUpdated, now).toMinutes() <= 5) {
                    Map<String, Object> row = new HashMap<>();
                    row.put("kerbsideid", Integer.parseInt(parts[4]));
                    row.put("lastupdated", parts[0]);
                    row.put("status_timestamp", parts[1]);
                    row.put("status_description", parts[3]);
                    rows.add(row);
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public List<Map<String, Object>> getRows() {
        rows.sort(Comparator.comparingInt(r -> (Integer) r.get("kerbsideid")));
        return rows;
    }

    public void updateDatabase() {
        String sql =
                "UPDATE public.parking_bay_realtime " +
                "SET lastupdated = ?, " +
                "    status_timestamp = ?, " +
                "    status_description = ?::occupancy_status " +
                "WHERE kerbsideid = ?;";

        for (Map<String, Object> row : rows) {
            var lastUpdated = OffsetDateTime.parse((String) row.get("lastupdated")).toLocalDateTime();
            var statusTs    = OffsetDateTime.parse((String) row.get("status_timestamp")).toLocalDateTime();

            jdbc.update(sql,
                    lastUpdated,
                    statusTs, 
                    (String) row.get("status_description"),        
                    (Integer) row.get("kerbsideid"));              
        }
    }
}