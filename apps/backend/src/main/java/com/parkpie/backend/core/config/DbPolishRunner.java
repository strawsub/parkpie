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

        // Clean up any legacy indexes created in earlier dev iterations
        jdbc.execute("DROP INDEX IF EXISTS uq_bay_seg_kerb_when_present");
        jdbc.execute("DROP INDEX IF EXISTS uq_bay_seg_lat_lng_when_missing_kerb");
    }
}
