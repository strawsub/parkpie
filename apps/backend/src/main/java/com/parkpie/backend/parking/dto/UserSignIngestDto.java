package com.parkpie.backend.parking.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.time.LocalTime;
import java.util.List;

public class UserSignIngestDto {

    public static class Location {
        @NotNull
        @DecimalMin("-90.0") @DecimalMax("90.0")
        public Double lat;

        @NotNull
        @DecimalMin("-180.0") @DecimalMax("180.0")
        public Double lng;
    }

    public static class Restriction {
        @NotNull @Min(1) @Max(7)
        public Integer day_of_week; // 1..7 (Mon..Sun)

        @NotNull
        public LocalTime start_time; // HH:mm

        @NotNull
        public LocalTime end_time;   // HH:mm

        @PositiveOrZero
        public Integer maximum_stay_minutes;
    }

    public static class Request {
        @NotNull @Valid
        public Location location;

        @Valid
        @NotNull @Size(min = 1, max = 42)
        public List<Restriction> restrictions;

        @Negative
        public Integer zone_number;
    }

    public static class Response {
        public int zone_number;
        public int restrictions_saved;
        public int replaced_previous;

        public Response(int zoneNumber, int restrictionsSaved, int replacedPrevious) {
            this.zone_number = zoneNumber;
            this.restrictions_saved = restrictionsSaved;
            this.replaced_previous = replacedPrevious;
        }
    }
}
