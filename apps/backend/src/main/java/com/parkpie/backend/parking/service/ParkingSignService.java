package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ParkingSignService {

    private final ParkingSignRepository parkingSignRepository;

    public ParkingSignService(ParkingSignRepository parkingSignRepository) {
        this.parkingSignRepository = parkingSignRepository;
    }

    @Transactional(readOnly = true)
    public List<ParkingSignDto.SignView> findNear(double lat, double lng, double meters) {
        return parkingSignRepository.findNear(lat, lng, meters).stream()
                .map(nearView -> new ParkingSignDto.SignView(nearView.getId(), nearView.getText(), nearView.getLat(), nearView.getLng()))
                .toList();
    }
}
