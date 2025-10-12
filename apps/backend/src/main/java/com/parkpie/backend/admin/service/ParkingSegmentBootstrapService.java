package com.parkpie.backend.admin.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Ensures the auxiliary parking tables are present and seeded with the default data needed by the dashboard.
 * The tables historically were created manually after DB resets; this service makes the process deterministic.
 */
@Service
public class ParkingSegmentBootstrapService {

    private final JdbcTemplate jdbc;

    private record SegmentSeed(
            String label,
            double swLng, double swLat,
            double neLng, double neLat,
            double centerLng, double centerLat) {}

    private static final List<SegmentSeed> DEFAULT_SEGMENTS = List.of(
            new SegmentSeed("CBD",
                    144.952404, -37.821975,
                    144.965086, -37.806830,
                    144.957764, -37.814687),
            new SegmentSeed("Exhibition",
                    144.965107, -37.819280,
                    144.974784, -37.806907,
                    144.969385, -37.812419),
            new SegmentSeed("East Melbourne",
                    144.974707, -37.815430,
                    144.991408, -37.808655,
                    144.982362, -37.812566),
            new SegmentSeed("Docklands Yarra Side",
                    144.940629, -37.823307,
                    144.952317, -37.815116,
                    144.946072, -37.820141),
            new SegmentSeed("Docklands Waterfront",
                    144.933781, -37.815496,
                    144.952300, -37.809201,
                    144.939131, -37.813609),
            new SegmentSeed("North Melbourne",
                    144.946975, -37.807090,
                    144.970498, -37.797487,
                    144.957455, -37.800017),
            new SegmentSeed("Khue House",
                    145.098614, -37.793114,
                    145.103991, -37.789584,
                    145.101068, -37.791741)
    );

    public ParkingSegmentBootstrapService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Create the parking_session/parking_segments tables (if missing) and seed the static segment rows.
     * Idempotent: safe to call after every Step 3 upload.
     */
    @Transactional
    public void ensureStaticTables() {
        createParkingSessionTable();
        createParkingSegmentsTable();
        seedParkingSegments();
    }

    private void createParkingSessionTable() {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS public.parking_session (
                    session_id SERIAL PRIMARY KEY,
                    location GEOMETRY(POINT, 4326) NOT NULL,
                    start_parking_time TIME(6) NOT NULL,
                    created_at TIMESTAMP(6) DEFAULT NOW(),
                    parking_sign_id INTEGER NOT NULL
                )
                """);

        jdbc.execute("""
                CREATE INDEX IF NOT EXISTS idx_parking_session_location
                ON public.parking_session
                USING GIST (location)
                """);
        jdbc.execute("""
                CREATE INDEX IF NOT EXISTS idx_parking_session_sign
                ON public.parking_session (parking_sign_id)
                """);

        jdbc.execute("""
                DO $$
                BEGIN
                  IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'fk_parking_session_sign'
                  ) THEN
                    ALTER TABLE public.parking_session
                    ADD CONSTRAINT fk_parking_session_sign
                    FOREIGN KEY (parking_sign_id)
                    REFERENCES public.parking_signs (id)
                    ON DELETE CASCADE;
                  END IF;
                END
                $$;
                """);
    }

    private void createParkingSegmentsTable() {
        jdbc.execute("""
                CREATE TABLE IF NOT EXISTS public.parking_segments (
                    id SERIAL PRIMARY KEY,
                    label VARCHAR(100) NOT NULL UNIQUE,
                    location_sw GEOMETRY(POINT, 4326) NOT NULL,
                    location_ne GEOMETRY(POINT, 4326) NOT NULL,
                    location_center GEOMETRY(POINT, 4326) NOT NULL,
                    created_at TIMESTAMP(6) DEFAULT NOW()
                )
                """);

        jdbc.execute("""
                CREATE INDEX IF NOT EXISTS idx_parking_segments_center
                ON public.parking_segments
                USING GIST (location_center)
                """);
    }

    private void seedParkingSegments() {
        String sql = """
                INSERT INTO public.parking_segments (
                    label, location_sw, location_ne, location_center
                )
                VALUES (
                    ?,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326),
                    ST_SetSRID(ST_MakePoint(?, ?), 4326),
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)
                )
                ON CONFLICT (label) DO UPDATE SET
                    location_sw = EXCLUDED.location_sw,
                    location_ne = EXCLUDED.location_ne,
                    location_center = EXCLUDED.location_center
                """;

        for (SegmentSeed seed : DEFAULT_SEGMENTS) {
            jdbc.update(sql,
                    seed.label(),
                    seed.swLng(), seed.swLat(),
                    seed.neLng(), seed.neLat(),
                    seed.centerLng(), seed.centerLat());
        }
    }
}

