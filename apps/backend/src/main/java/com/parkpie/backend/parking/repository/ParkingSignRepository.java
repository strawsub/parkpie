package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingSign;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ParkingSignRepository extends JpaRepository<ParkingSign, Long> {

    interface NearView {
        Long getId();
        String getText();
        double getLat();
        double getLng();
    }

    @Query(value =
        """
        SELECT id,text, ST_Y(location)::float8 AS lat, ST_X(location)::float8 AS lng
        FROM parking_signs
        WHERE ST_DWithin(location::geography, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :meters)
        """, nativeQuery = true)
    List<NearView> findNear(@Param("lat") double lat, @Param("lng") double lng, @Param("meters") double meters);
}
