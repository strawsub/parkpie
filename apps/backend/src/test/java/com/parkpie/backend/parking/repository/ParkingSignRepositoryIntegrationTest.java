package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingSign;
import com.parkpie.backend.support.PostgresIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIf;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration tests exercising custom queries in {@link ParkingSignRepository}.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@EnabledIf("com.parkpie.backend.support.PostgresIntegrationTest#isContainerAvailable")
class ParkingSignRepositoryIntegrationTest extends PostgresIntegrationTest {

    @Autowired
    private ParkingSignRepository repository;

    @Autowired
    private GeometryFactory geometryFactory;

    @Test
    @DisplayName("findNear returns results sorted by distance within the requested radius")
    void findNearReturnsOrderedResults() {
        repository.deleteAllInBatch();

        saveSign(-101, -37.8136, 144.9631, 1, LocalTime.of(8, 0), LocalTime.of(18, 0), 60);
        saveSign(-102, -37.8200, 144.9700, 1, LocalTime.of(9, 0), LocalTime.of(17, 0), 120);

        List<ParkingSignRepository.NearView> views = repository.findNear(-37.8140, 144.9633, 1500);

        assertThat(views).hasSize(2);
        assertThat(views.get(0).getText()).contains("Zone -101");
        assertThat(views.get(1).getText()).contains("Zone -102");
    }

    @Test
    @DisplayName("findRestrictionWindowsNear returns matching manual zones ordered by distance")
    void findRestrictionWindowsNearReturnsWindows() {
        repository.deleteAllInBatch();

        saveSign(-200, -37.8130, 144.9630, 2, LocalTime.of(7, 0), LocalTime.of(19, 0), 120);
        saveSign(-200, -37.8130, 144.9630, 5, LocalTime.of(9, 0), LocalTime.of(15, 0), 30);
        saveSign(-150, -37.8205, 144.9705, 3, LocalTime.of(10, 0), LocalTime.of(16, 0), null);

        List<ParkingSignRepository.RestrictionWindowView> windows =
                repository.findRestrictionWindowsNear(-37.8132, 144.9635, 2000);

        assertThat(windows).extracting(ParkingSignRepository.RestrictionWindowView::getZoneNumber)
                .containsExactly(-200, -200, -150);
        assertThat(windows.get(0).getDayOfWeek()).isEqualTo(2);
        assertThat(windows.get(1).getMaximumStayMinutes()).isEqualTo(30);
    }

    @Test
    @DisplayName("upsertManual inserts new rows and updates existing zone windows")
    void upsertManualPersistsAndUpdates() {
        repository.deleteAllInBatch();

        int inserted = repository.upsertManual(
                -300,
                -37.80,
                144.95,
                1,
                LocalTime.of(8, 0),
                LocalTime.of(10, 0),
                60,
                LocalDateTime.now()
        );
        assertThat(inserted).isEqualTo(1);

        int updated = repository.upsertManual(
                -300,
                -37.801,
                144.951,
                1,
                LocalTime.of(8, 0),
                LocalTime.of(10, 0),
                90,
                LocalDateTime.now()
        );
        assertThat(updated).isEqualTo(1);

        List<ParkingSignRepository.RestrictionWindowView> windows =
                repository.findRestrictionWindowsNear(-37.801, 144.951, 50);
        assertThat(windows).hasSize(1);
        assertThat(windows.get(0).getMaximumStayMinutes()).isEqualTo(90);

        int deleted = repository.deleteByZone(-300);
        assertThat(deleted).isGreaterThanOrEqualTo(1);
    }

    @Test
    @DisplayName("nextManualZoneSequence yields increasing positive identifiers")
    void nextManualZoneSequenceIncrements() {
        long first = repository.nextManualZoneSequence();
        long second = repository.nextManualZoneSequence();
        assertThat(first).isPositive();
        assertThat(second).isEqualTo(first + 1);
    }

    private void saveSign(int zoneNumber,
                          double lat,
                          double lng,
                          int dayOfWeek,
                          LocalTime start,
                          LocalTime end,
                          Integer maxStay) {
        ParkingSign sign = new ParkingSign();
        sign.setZoneNumber(zoneNumber);
        sign.setDayOfWeek(dayOfWeek);
        sign.setStartTime(start);
        sign.setEndTime(end);
        sign.setMaximumStayMinutes(maxStay);
        sign.setUpdatedAt(LocalDateTime.now());
        sign.setLocation(point(lng, lat));
        repository.saveAndFlush(sign);
    }

    private org.locationtech.jts.geom.Point point(double lng, double lat) {
        org.locationtech.jts.geom.Point point = geometryFactory.createPoint(new Coordinate(lng, lat));
        point.setSRID(4326);
        return point;
    }
}
