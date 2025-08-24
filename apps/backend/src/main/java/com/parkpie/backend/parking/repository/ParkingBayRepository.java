package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.ParkingBay;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ParkingBayRepository extends JpaRepository<ParkingBay, Long> {

}
