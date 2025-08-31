package com.parkpie.backend.parking.repository;

import com.parkpie.backend.parking.entity.PayStayZoneLink;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface PayStayZoneLinkRepository extends JpaRepository<PayStayZoneLink, Long> {

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Transactional
    @Query(value = """
        INSERT INTO pay_stay_zone_links(pay_stay_zone, street_segment_id, street, between_street_1, between_street_2)
        VALUES (:zone, :seg, :street, :b1, :b2)
        ON CONFLICT (pay_stay_zone, street_segment_id)
        DO UPDATE SET
            street = EXCLUDED.street,
            between_street_1 = EXCLUDED.between_street_1,
            between_street_2 = EXCLUDED.between_street_2
        """, nativeQuery = true)
    int upsertLink(@Param("zone") String zone,
                   @Param("seg") long streetSegmentId,
                   @Param("street") String street,
                   @Param("b1") String between1,
                   @Param("b2") String between2);
}
