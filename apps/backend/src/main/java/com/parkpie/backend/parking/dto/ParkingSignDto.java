package com.parkpie.backend.parking.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;

/**
 * DTO types describing parking sign payloads used by the API and admin workflows.
 */
public class ParkingSignDto {

    private ParkingSignDto() {
    }

    /**
     * Request payload used by administrators when creating parking signs.
     */
    @Schema(description = "Create request payload for a parking sign maintained by admins.")
    public static class CreateRequest {

        /** Text shown on the physical parking sign. */
        @Schema(description = "Text shown on the physical parking sign.", example = "1P 8AM - 6PM MON-FRI")
        @NotBlank
        public String text;

        /** Latitude in WGS84 decimal degrees. */
        @Schema(description = "Latitude in WGS84 decimal degrees.", example = "-37.8136")
        @DecimalMin(value="-90.0") @DecimalMax(value="90.0")
        public double lat;

        /** Longitude in WGS84 decimal degrees. */
        @Schema(description = "Longitude in WGS84 decimal degrees.", example = "144.9631")
        @DecimalMin(value="-180.0") @DecimalMax(value="180.0")
        public double lng;

        /**
         * Creates an empty request payload.
         */
        public CreateRequest() {
        }
    }

    /**
     * Projection returned to clients describing a parking sign.
     */
    @Schema(description = "Projection of a single parking sign shown to clients.")
    public static class SignView {
        /** Unique identifier of the sign. */
        @Schema(description = "Unique identifier of the sign.", example = "42")
        public Long id;

        /** Human readable sign text. */
        @Schema(description = "Human readable sign text.", example = "1P 8AM - 6PM MON-FRI")
        public String text;

        /** Latitude in WGS84 decimal degrees. */
        @Schema(description = "Latitude in WGS84 decimal degrees.", example = "-37.8135")
        public double lat;

        /** Longitude in WGS84 decimal degrees. */
        @Schema(description = "Longitude in WGS84 decimal degrees.", example = "144.9632")
        public double lng;

        /**
         * Creates a projection of a parking sign.
         *
         * @param id identifier of the sign
         * @param text human readable sign text
         * @param lat latitude in WGS84 decimal degrees
         * @param lng longitude in WGS84 decimal degrees
         */
        public SignView(Long id, String text, double lat, double lng) {
            this.id = id;
            this.text = text;
            this.lat = lat;
            this.lng = lng;
        }
    }
}
