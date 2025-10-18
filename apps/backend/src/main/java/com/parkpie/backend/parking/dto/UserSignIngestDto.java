package com.parkpie.backend.parking.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Negative;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.time.LocalTime;
import java.util.List;

/**
 * DTO types describing payloads exchanged when users ingest manual parking signs.
 */
public class UserSignIngestDto {

    private UserSignIngestDto() {
    }

    /**
     * User supplied geolocation for the parking sign.
     */
    @Schema(description = "User supplied geolocation of the parking sign.")
    public static class Location {
        @Schema(description = "Latitude in WGS84 decimal degrees.", example = "-37.8136")
        @NotNull
        @DecimalMin("-90.0") @DecimalMax("90.0")
        /** Latitude in WGS84 decimal degrees. */
        public Double lat;

        @Schema(description = "Longitude in WGS84 decimal degrees.", example = "144.9631")
        @NotNull
        @DecimalMin("-180.0") @DecimalMax("180.0")
        /** Longitude in WGS84 decimal degrees. */
        public Double lng;

        /**
         * Creates an empty location.
         */
        public Location() {
        }
    }

    /**
     * Restriction window describing when the sign applies.
     */
    @Schema(description = "Restriction window that applies to the parking zone.")
    public static class Restriction {
        @Schema(description = "ISO day of week where Monday = 1.", example = "1")
        @NotNull @Min(1) @Max(7)
        /** ISO day-of-week where Monday equals 1. */
        public Integer day_of_week; // 1..7 (Mon..Sun)

        @Schema(description = "Start time in HH:mm format.", example = "08:00")
        @NotNull
        /** Restriction start time. */
        public LocalTime start_time; // HH:mm

        @Schema(description = "End time in HH:mm format.", example = "18:00")
        @NotNull
        /** Restriction end time. */
        public LocalTime end_time;   // HH:mm

        @Schema(description = "Maximum stay duration in minutes, 0 for no limit.", example = "120")
        @PositiveOrZero
        /** Maximum stay minutes, or zero for no limit. */
        public Integer maximum_stay_minutes;

        /**
         * Creates an empty restriction window.
         */
        public Restriction() {
        }
    }

    /**
     * Request payload submitted by the mobile app to ingest a parking sign.
     */
    @Schema(description = "Request payload used by the mobile app to upload a parking sign.")
    public static class Request {
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED)
        @NotNull @Valid
        /** Location of the sign being submitted. */
        public Location location;

        @Schema(description = "Restriction windows to apply to the created zone.", requiredMode = Schema.RequiredMode.REQUIRED)
        @Valid
        @NotNull @Size(min = 1, max = 42)
        /** Restriction windows describing the sign rules. */
        public List<Restriction> restrictions;

        @Schema(description = "Negative identifier assigned to manually created zones.", example = "-1234")
        @Negative
        /** Optional manual zone identifier when updating an existing zone. */
        public Integer zone_number;

        /**
         * Creates an empty request payload.
         */
        public Request() {
        }
    }

    /**
     * Response payload summarising ingestion outcomes.
     */
    @Schema(description = "Response payload summarising the result of the ingestion.")
    public static class Response {
        @Schema(description = "Zone identifier assigned to the sign.", example = "-1234")
        /** Assigned zone identifier. */
        public int zone_number;

        @Schema(description = "Number of restriction windows persisted.", example = "3")
        /** Number of restrictions stored. */
        public int restrictions_saved;

        @Schema(description = "Number of previously stored windows replaced by this submission.", example = "1")
        /** Number of restriction windows replaced by the submission. */
        public int replaced_previous;

        /**
         * Creates a response summary.
         *
         * @param zoneNumber assigned zone number
         * @param restrictionsSaved number of restrictions saved
         * @param replacedPrevious number of restrictions replaced
         */
        public Response(int zoneNumber, int restrictionsSaved, int replacedPrevious) {
            this.zone_number = zoneNumber;
            this.restrictions_saved = restrictionsSaved;
            this.replaced_previous = replacedPrevious;
        }

        /**
         * Creates an empty response payload.
         */
        public Response() {
            this(0, 0, 0);
        }
    }
}
