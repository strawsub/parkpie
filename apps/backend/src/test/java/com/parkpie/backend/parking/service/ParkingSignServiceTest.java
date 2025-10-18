package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.UserSignIngestDto;
import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

import java.time.LocalTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.never;

/**
 * Unit tests covering the manual parking sign ingestion workflow.
 */
class ParkingSignServiceTest {

    private ParkingSignRepository repository;
    private ParkingSignService service;

    @BeforeEach
    void setUp() {
        repository = Mockito.mock(ParkingSignRepository.class);
        service = new ParkingSignService(repository);
    }

    @Test
    void reusesExistingManualZoneWhenRestrictionsMatch() {
        double lat = -37.7922;
        double lng = 145.1020;

        var request = buildRequest(lat, lng,
                restriction(1, LocalTime.of(8, 30), LocalTime.of(18, 0), 60),
                restriction(2, LocalTime.of(8, 30), LocalTime.of(18, 0), 60)
        );

        Mockito.when(repository.findRestrictionWindowsNear(eq(lat), eq(lng), anyDouble()))
                .thenReturn(List.of(
                        window(-101, 1, LocalTime.of(8, 30), LocalTime.of(18, 0), 60, 4.2),
                        window(-101, 2, LocalTime.of(8, 30), LocalTime.of(18, 0), 60, 4.5)
                ));
        Mockito.when(repository.deleteByZone(-101)).thenReturn(6);
        Mockito.when(repository.upsertManual(eq(-101), eq(lat), eq(lng), anyInt(), any(), any(), any(), any()))
                .thenReturn(1);

        var response = service.ingestUserSign(request);

        assertThat(response.zone_number).isEqualTo(-101);
        assertThat(response.replaced_previous).isEqualTo(6);
        Mockito.verify(repository, never()).nextManualZoneSequence();

        ArgumentCaptor<Double> radius = ArgumentCaptor.forClass(Double.class);
        Mockito.verify(repository).findRestrictionWindowsNear(eq(lat), eq(lng), radius.capture());
        assertThat(radius.getValue()).isEqualTo(15.0);
    }

    @Test
    void allocatesNewZoneWhenNoMatchFound() {
        double lat = -37.8000;
        double lng = 145.1100;

        var request = buildRequest(lat, lng,
                restriction(3, LocalTime.of(7, 0), LocalTime.of(16, 0), 30)
        );

        Mockito.when(repository.findRestrictionWindowsNear(eq(lat), eq(lng), anyDouble()))
                .thenReturn(List.of());
        Mockito.when(repository.nextManualZoneSequence()).thenReturn(5L);
        Mockito.when(repository.upsertManual(eq(-5), eq(lat), eq(lng), anyInt(), any(), any(), any(), any()))
                .thenReturn(1);

        var response = service.ingestUserSign(request);

        assertThat(response.zone_number).isEqualTo(-5);
        assertThat(response.replaced_previous).isZero();
        Mockito.verify(repository, never()).deleteByZone(anyInt());
    }

    @Test
    void rejectsPositiveManualZoneNumber() {
        var location = new UserSignIngestDto.Location();
        location.lat = -37.81;
        location.lng = 144.96;

        var restriction = restriction(1, LocalTime.of(8, 0), LocalTime.of(18, 0), 120);

        var request = new UserSignIngestDto.Request();
        request.location = location;
        request.restrictions = List.of(restriction);
        request.zone_number = 5;

        assertThatThrownBy(() -> service.ingestUserSign(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Manual zone_number must be negative");
    }

    @Test
    void throwsWhenManualZoneSequenceReturnsInvalidValue() {
        Mockito.when(repository.findRestrictionWindowsNear(anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(List.of());
        Mockito.when(repository.nextManualZoneSequence()).thenReturn(0L);

        var request = buildRequest(-37.8, 144.95,
                restriction(2, LocalTime.of(7, 0), LocalTime.of(10, 0), 60)
        );

        assertThatThrownBy(() -> service.ingestUserSign(request))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("invalid value");
    }

    private static UserSignIngestDto.Request buildRequest(double lat, double lng, UserSignIngestDto.Restriction... restrictions) {
        var location = new UserSignIngestDto.Location();
        location.lat = lat;
        location.lng = lng;

        var request = new UserSignIngestDto.Request();
        request.location = location;
        request.restrictions = List.of(restrictions);
        request.zone_number = null;
        return request;
    }

    private static UserSignIngestDto.Restriction restriction(int dow, LocalTime start, LocalTime end, Integer maxStay) {
        var r = new UserSignIngestDto.Restriction();
        r.day_of_week = dow;
        r.start_time = start;
        r.end_time = end;
        r.maximum_stay_minutes = maxStay;
        return r;
    }

    private static ParkingSignRepository.RestrictionWindowView window(
            int zoneNumber,
            int dayOfWeek,
            LocalTime start,
            LocalTime end,
            Integer maxStay,
            double distance
    ) {
        return new ParkingSignRepository.RestrictionWindowView() {
            @Override
            public Integer getZoneNumber() {
                return zoneNumber;
            }

            @Override
            public Integer getDayOfWeek() {
                return dayOfWeek;
            }

            @Override
            public LocalTime getStartTime() {
                return start;
            }

            @Override
            public LocalTime getEndTime() {
                return end;
            }

            @Override
            public Integer getMaximumStayMinutes() {
                return maxStay;
            }

            @Override
            public double getDistanceMeters() {
                return distance;
            }
        };
    }
}
