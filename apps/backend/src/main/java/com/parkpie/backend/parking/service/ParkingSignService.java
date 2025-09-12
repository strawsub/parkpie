package com.parkpie.backend.parking.service;

import com.parkpie.backend.parking.dto.ParkingSignDto;
import com.parkpie.backend.parking.dto.UserSignIngestDto;
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

    @Transactional
    public int ingestUserSign(UserSignIngestDto.Request req) {
        // Validate 7 unique days 1..7
        boolean[] seen = new boolean[8];
        for (var r : req.restrictions) {
            int d = r.day_of_week;
            if (d < 1 || d > 7) throw new IllegalArgumentException("day_of_week out of range: " + d);
            if (seen[d]) throw new IllegalArgumentException("Duplicate day_of_week: " + d);
            seen[d] = true;
        }
        for (int d = 1; d <= 7; d++) {
            if (!seen[d]) throw new IllegalArgumentException("Missing day_of_week: " + d);
        }

        int inserted = 0;
        for (var r : req.restrictions) {
            inserted += parkingSignRepository.insertManual(
                    req.location.lat, req.location.lng,
                    r.day_of_week, r.start_time, r.end_time, r.maximum_stay_minutes
            );
        }
        return inserted;
    }
}
