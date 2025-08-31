package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.entity.ParkingSign;
import com.parkpie.backend.parking.repository.ParkingSignRepository;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ParkingSignService {

    private final ParkingSignRepository parkingSignRepository;
    private final GeometryFactory geometryFactory;

    public ParkingSignService(ParkingSignRepository parkingSignRepository, GeometryFactory geometryFactory) {
        this.parkingSignRepository = parkingSignRepository;
        this.geometryFactory = geometryFactory;
    }

    @Transactional
    public ParkingSignDto.SignView create(ParkingSignDto.CreateRequest request) {
        Point point = geometryFactory.createPoint(new Coordinate(request.lng, request.lat)); // lng,lat
        ParkingSign parkingSign = new ParkingSign();
        parkingSign.setText(request.text);
        parkingSign.setLocation(point);
        ParkingSign saved = parkingSignRepository.save(parkingSign);
        return new ParkingSignDto.SignView(saved.getId(), saved.getText(), request.lat, request.lng);
    }

    @Transactional(readOnly = true)
    public List<ParkingSignDto.SignView> findNear(double lat, double lng, double meters) {
        return parkingSignRepository.findNear(lat, lng, meters).stream()
                .map(nearView -> new ParkingSignDto.SignView(nearView.getId(), nearView.getText(), nearView.getLat(), nearView.getLng()))
                .toList();
    }
}
