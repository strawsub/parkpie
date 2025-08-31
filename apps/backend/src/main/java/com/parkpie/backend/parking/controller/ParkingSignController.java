package com.parkpie.backend.parking.controller;

import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.service.ParkingSignService;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Positive;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping(value = "/signs", produces = "application/json")
@Validated
public class ParkingSignController {

    private final ParkingSignService service;

    public ParkingSignController(ParkingSignService service) {
        this.service = service;
    }

    @PostMapping(consumes = "application/json")
    public ResponseEntity<ParkingSignDto.SignView> create(@Validated @RequestBody ParkingSignDto.CreateRequest request) {
        return ResponseEntity.ok(service.create(request));
    }

    @GetMapping("/near")
    public List<ParkingSignDto.SignView> near(
            @RequestParam @DecimalMin("-90.0") @DecimalMax("90.0") double lat,
            @RequestParam @DecimalMin("-180.0") @DecimalMax("180.0") double lng,
            @RequestParam(defaultValue = "500") @Positive double meters) {
        return service.findNear(lat, lng, meters);
    }
}
