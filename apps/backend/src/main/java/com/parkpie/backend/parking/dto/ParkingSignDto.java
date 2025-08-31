package com.parkpie.backend.parking.dto;

import jakarta.validation.constraints.*;

public class ParkingSignDto {

    public static class CreateRequest {

        @NotBlank
        public String text;

        // WGS84 ranges
        @DecimalMin(value="-90.0") @DecimalMax(value="90.0")
        public double lat;

        @DecimalMin(value="-180.0") @DecimalMax(value="180.0")
        public double lng;
    }

    public static class SignView {
        public Long id;
        public String text;
        public double lat;
        public double lng;
        public SignView(Long id, String text, double lat, double lng) {
            this.id = id;
            this.text = text;
            this.lat = lat;
            this.lng = lng;
        }
    }
}
