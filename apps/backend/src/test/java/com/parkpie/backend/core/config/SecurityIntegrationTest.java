package com.parkpie.backend.core.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.parkpie.backend.admin.controller.AdminPageController;
import com.parkpie.backend.admin.service.AdminDatabaseService;
import com.parkpie.backend.parking.controller.ParkingSignController;
import com.parkpie.backend.core.controller.HealthController;
import com.parkpie.backend.parking.dto.UserSignIngestDto;
import com.parkpie.backend.parking.service.ParkingSignService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.GeometryFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalTime;
import java.util.List;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Integration tests verifying security constraints on admin and public endpoints.
 */
@WebMvcTest(controllers = {
        ParkingSignController.class,
        HealthController.class,
        AdminPageController.class
})
@Import({SecurityConfig.class, GeoConfig.class})
@TestPropertySource(properties = {
        "admin.username=test-admin",
        "admin.password=test-pass"
})
class SecurityIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private ParkingSignService parkingSignService;

    @MockBean
    private AdminDatabaseService adminDatabaseService;

    @MockBean
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private GeometryFactory geometryFactory;

    @Test
    @DisplayName("Admin endpoints require authentication")
    void adminEndpointRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/admin/health"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(username = "admin", roles = "ADMIN")
    @DisplayName("Admin endpoints respond for authenticated admin user")
    void adminEndpointAccessibleWithAdminRole() throws Exception {
        when(adminDatabaseService.fetchDbInfo()).thenReturn(Map.of("db", "ok"));
        mockMvc.perform(get("/admin/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    @DisplayName("Public health endpoint stays open")
    void healthEndpointIsPublic() throws Exception {
        when(jdbcTemplate.queryForObject(eq("SELECT 1"), eq(Integer.class))).thenReturn(1);
        when(jdbcTemplate.queryForObject(eq("SELECT version()"), eq(String.class))).thenReturn("PostgreSQL 16");

        mockMvc.perform(get("/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ok").value(true));
    }

    @Test
    @DisplayName("Sign ingestion allows POST without CSRF token")
    void signIngestionAllowsAnonymousPostWithoutCsrf() throws Exception {
        UserSignIngestDto.Location location = new UserSignIngestDto.Location();
        location.lat = -37.8;
        location.lng = 144.95;

        UserSignIngestDto.Restriction restriction = new UserSignIngestDto.Restriction();
        restriction.day_of_week = 2;
        restriction.start_time = LocalTime.of(7, 0);
        restriction.end_time = LocalTime.of(19, 0);
        restriction.maximum_stay_minutes = 180;

        UserSignIngestDto.Request request = new UserSignIngestDto.Request();
        request.location = location;
        request.restrictions = List.of(restriction);

        when(parkingSignService.ingestUserSign(any(UserSignIngestDto.Request.class)))
                .thenReturn(new UserSignIngestDto.Response(-5, 1, 0));

        mockMvc.perform(post("/signs/ingest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.zone_number").value(-5));
    }
}
