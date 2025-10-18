package com.parkpie.backend.parking.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.parkpie.backend.core.config.SecurityConfig;
import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.dto.UserSignIngestDto;
import com.parkpie.backend.parking.service.ParkingSignService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalTime;
import java.util.List;

import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Web MVC tests covering parking sign retrieval and ingestion endpoints.
 */
@WebMvcTest(controllers = ParkingSignController.class)
@Import(SecurityConfig.class)
@TestPropertySource(properties = {
        "admin.username=test-admin",
        "admin.password=test-pass"
})
class ParkingSignControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private ParkingSignService parkingSignService;

    @Test
    @DisplayName("GET /signs/near returns nearby signs with validation applied")
    void nearReturnsList() throws Exception {
        List<ParkingSignDto.SignView> signs = List.of(
                new ParkingSignDto.SignView(1L, "Zone A", -37.81, 144.96),
                new ParkingSignDto.SignView(2L, "Zone B", -37.82, 144.97)
        );
        when(parkingSignService.findNear(-37.81, 144.96, 250)).thenReturn(signs);

        mockMvc.perform(get("/signs/near")
                        .param("lat", "-37.81")
                        .param("lng", "144.96")
                        .param("meters", "250"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].text").value("Zone A"))
                .andExpect(jsonPath("$[1].id").value(2))
                .andExpect(jsonPath("$[1].lat").value(-37.82));

        verify(parkingSignService).findNear(-37.81, 144.96, 250.0);
    }

    @Test
    @DisplayName("GET /signs/near rejects out-of-range coordinates")
    void nearRejectsInvalidCoordinates() throws Exception {
        mockMvc.perform(get("/signs/near")
                        .param("lat", "200.0")
                        .param("lng", "144.96"))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(parkingSignService);
    }

    @Test
    @DisplayName("POST /signs/ingest validates request payload and injects into service")
    void ingestValidatesAndDelegates() throws Exception {
        UserSignIngestDto.Location location = new UserSignIngestDto.Location();
        location.lat = -37.8;
        location.lng = 144.95;

        UserSignIngestDto.Restriction restriction = new UserSignIngestDto.Restriction();
        restriction.day_of_week = 3;
        restriction.start_time = LocalTime.of(8, 0);
        restriction.end_time = LocalTime.of(18, 0);
        restriction.maximum_stay_minutes = 120;

        UserSignIngestDto.Request request = new UserSignIngestDto.Request();
        request.location = location;
        request.restrictions = List.of(restriction);

        UserSignIngestDto.Response response = new UserSignIngestDto.Response(-10, 1, 0);
        when(parkingSignService.ingestUserSign(any(UserSignIngestDto.Request.class))).thenReturn(response);

        mockMvc.perform(post("/signs/ingest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.zone_number").value(-10))
                .andExpect(jsonPath("$.restrictions_saved").value(1))
                .andExpect(jsonPath("$.replaced_previous").value(0));

        verify(parkingSignService).ingestUserSign(any(UserSignIngestDto.Request.class));
    }

    @Test
    @DisplayName("POST /signs/ingest rejects empty restrictions collection")
    void ingestRejectsMissingRestrictions() throws Exception {
        UserSignIngestDto.Location location = new UserSignIngestDto.Location();
        location.lat = -37.8;
        location.lng = 144.95;

        UserSignIngestDto.Request request = new UserSignIngestDto.Request();
        request.location = location;
        request.restrictions = List.of();

        mockMvc.perform(post("/signs/ingest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(request)))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(parkingSignService);
    }
}
