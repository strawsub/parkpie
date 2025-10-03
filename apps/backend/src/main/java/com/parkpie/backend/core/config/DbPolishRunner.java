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

        // Helpful index for joins/lookups by kerbside_id
        jdbc.execute("""
            CREATE INDEX IF NOT EXISTS idx_parking_bays_kerbside_id
            ON parking_bays(kerbside_id)
        """);

        // Ensure uniqueness for bays without KerbsideID using (segment, lat, lng)
        jdbc.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS uq_bay_seg_lat_lng_when_missing_kerb
            ON parking_bays(street_segment_id, lat, lng)
            WHERE kerbside_id IS NULL
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

        // Clean up any legacy indexes created in earlier dev iterations (kept if useful)
        jdbc.execute("DROP INDEX IF EXISTS uq_bay_seg_kerb_when_present");

        // Realtime table small adjustments (non-destructive)
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_bay_realtime ADD COLUMN IF NOT EXISTS zone_number integer");
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_parking_bay_realtime_zone ON public.parking_bay_realtime(zone_number)");

        // Parking signs schema helpers
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS zone_number integer");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS day_of_week integer");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS start_time time");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS end_time time");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS maximum_stay_minutes integer");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS occupancy_percent double precision");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS status_description");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS lat");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS lng");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS cost_per_hour_cents");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS bay_count");
        // Ensure legacy audit column doesn't reappear
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS created_at");

        // Drop deprecated columns if present
        // 'text' column removed from codebase; no longer referenced
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS minimum_stay_minutes");
        jdbc.execute("ALTER TABLE IF EXISTS public.parking_signs DROP COLUMN IF EXISTS day_of_week_name");

        // Unique constraint for (zone,window) rows
        jdbc.execute("""
            DO $$
            BEGIN
              IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'uq_sign_zone_window'
              ) THEN
                ALTER TABLE public.parking_signs
                  ADD CONSTRAINT uq_sign_zone_window UNIQUE(zone_number, day_of_week, start_time, end_time);
              END IF;
            END
            $$;
        """);

        // Availability fetch log table (basic structure, in case DDL update is constrained)
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS public.availability_fetch_log (
              id BIGSERIAL PRIMARY KEY,
              source varchar(32),
              started_at timestamp,
              ended_at timestamp,
              rows_fetched integer,
              signs_upserted integer,
              status varchar(32),
              message varchar(4000),
              error varchar(4000)
            )
        """);

        // Ensure occupancy_status enum exists and column uses it
        jdbc.execute("""
            DO $$
            BEGIN
              IF NOT EXISTS (
                SELECT 1 FROM pg_type WHERE typname = 'occupancy_status'
              ) THEN
                CREATE TYPE occupancy_status AS ENUM ('Present','Unoccupied');
              END IF;
            END
            $$;
        """);
        // Try to convert column to enum if possible
        jdbc.execute("""
            DO $$
            BEGIN
              IF EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'parking_bay_realtime'
                  AND column_name = 'status_description'
              ) THEN
                BEGIN
                  EXECUTE 'ALTER TABLE public.parking_bay_realtime ' ||
                          'ALTER COLUMN status_description TYPE occupancy_status USING status_description::occupancy_status';
                EXCEPTION WHEN others THEN
                  -- if conversion fails, keep as text
                  NULL;
                END;
              END IF;
            END
            $$;
        """);

        // Allow null for minimum_stay_minutes to match dataset (rare blanks)
        jdbc.execute("""
            DO $$
            BEGIN
              IF EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'pay_stay_restrictions'
                  AND column_name = 'minimum_stay_minutes'
                  AND is_nullable = 'NO'
              ) THEN
                EXECUTE 'ALTER TABLE public.pay_stay_restrictions ALTER COLUMN minimum_stay_minutes DROP NOT NULL';
              END IF;
            END
            $$;
        """);
        jdbc.execute("""
            DO $$
            BEGIN
              IF NOT EXISTS (
                SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'manual_zone_number_seq'
              ) THEN
                CREATE SEQUENCE manual_zone_number_seq START WITH 1;
              END IF;
            END
            $$;
        """);
    }
}






