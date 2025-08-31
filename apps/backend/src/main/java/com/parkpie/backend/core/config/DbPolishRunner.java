package com.parkpie.backend.core.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class DbPolishRunner implements ApplicationRunner {

    private final JdbcTemplate jdbc;

    public DbPolishRunner(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        try {
            // Check if the database connection is healthy
            jdbc.queryForObject("SELECT 1", Integer.class);
        } catch (Exception e) {
            System.err.println("⚠️  Cannot connect to database, skip index creation.");
            e.printStackTrace();
            return;
        }

        // Spatial index for fast map queries
        jdbc.execute("""
            CREATE INDEX IF NOT EXISTS idx_parking_bays_location
            ON parking_bays
            USING GIST (location)
        """);

        // Check constraint to guarantee non-negative kerbside_id
        jdbc.execute("""
            DO $$
            BEGIN
              IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'ck_parking_bays_kerbside_nonneg'
              ) THEN
                ALTER TABLE parking_bays
                  ADD CONSTRAINT ck_parking_bays_kerbside_nonneg
                  CHECK (kerbside_id >= 0);
              END IF;
            END
            $$;
        """);
    }
}
