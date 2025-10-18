package com.parkpie.backend.parking.controller;

import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.dto.UserSignIngestDto;
import com.parkpie.backend.parking.service.ParkingSignService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Positive;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping(value = "/signs", produces = "application/json")
@Tag(name = "Parking")
@Validated
public class ParkingSignController {

    private final ParkingSignService service;

    public ParkingSignController(ParkingSignService service) {
        this.service = service;
    }

    @GetMapping("/near")
    @Operation(
            summary = "Look up nearby parking signs",
            description = "Returns the closest parking signs to the supplied latitude and longitude, ordered by distance."
    )
    @ApiResponses({
            @ApiResponse(
                    responseCode = "200",
                    description = "Matching signs located near the provided coordinates.",
                    content = @Content(
                            mediaType = "application/json",
                            array = @ArraySchema(schema = @Schema(implementation = ParkingSignDto.SignView.class))
                    )
            ),
            @ApiResponse(responseCode = "400", description = "Invalid latitude, longitude or radius supplied.")
    })
    public List<ParkingSignDto.SignView> near(
            @Parameter(
                    description = "Latitude in WGS84 decimal degrees.",
                    required = true,
                    example = "-37.8136"
            )
            @RequestParam @DecimalMin("-90.0") @DecimalMax("90.0") double lat,
            @Parameter(
                    description = "Longitude in WGS84 decimal degrees.",
                    required = true,
                    example = "144.9631"
            )
            @RequestParam @DecimalMin("-180.0") @DecimalMax("180.0") double lng,
            @Parameter(
                    description = "Search radius in metres. Defaults to 500.",
                    example = "750"
            )
            @RequestParam(defaultValue = "500") @Positive double meters) {
        return service.findNear(lat, lng, meters);
    }

    @PostMapping(value = "/ingest", consumes = "application/json")
    @Operation(
            summary = "Submit a manually collected parking sign",
            description = "Stores a zone and restriction window provided by a user after validation.",
            requestBody = @RequestBody(
                    required = true,
                    description = "User-submitted parking sign payload.",
                    content = @Content(
                            mediaType = "application/json",
                            schema = @Schema(implementation = UserSignIngestDto.Request.class)
                    )
            )
    )
    @ApiResponses({
            @ApiResponse(
                    responseCode = "200",
                    description = "Sign processed successfully.",
                    content = @Content(
                            mediaType = "application/json",
                            schema = @Schema(implementation = UserSignIngestDto.Response.class)
                    )
            ),
            @ApiResponse(responseCode = "400", description = "Payload failed validation.")
    })
    public UserSignIngestDto.Response ingest(
            @Validated @org.springframework.web.bind.annotation.RequestBody UserSignIngestDto.Request request) {
        return service.ingestUserSign(request);
    }
}
