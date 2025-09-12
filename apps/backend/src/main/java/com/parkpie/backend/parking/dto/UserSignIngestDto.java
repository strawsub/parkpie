package com.parkpie.backend.parking.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.time.LocalTime;
import java.util.List;

public class UserSignIngestDto {

    public static class Location {
        @DecimalMin("-90.0") @DecimalMax("90.0")
        public double lat;
        @DecimalMin("-180.0") @DecimalMax("180.0")
        public double lng;
    }

    public static class Restriction {
        @NotNull @Min(1) @Max(7)
        public Integer day_of_week; // 1..7 (Mon..Sun)

        @NotNull
        public LocalTime start_time; // HH:mm

        @NotNull
        public LocalTime end_time;   // HH:mm

        @NotNull @Positive
        public Integer maximum_stay_minutes;
    }

    public static class Request {
        @NotNull @Valid
        public Location location;

        @NotNull @Size(min = 7, max = 7)
        @Valid
        public List<Restriction> restrictions;
    }
}

