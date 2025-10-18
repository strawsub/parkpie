package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;

/**
 * Entity representing a mapping between a PayStay zone and a street segment.
 */
@Entity
@Table(
        name = "pay_stay_zone_links",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_zone_segment",
                columnNames = {"pay_stay_zone","street_segment_id"}
        )
)
public class PayStayZoneLink {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "pay_stay_zone", length = 32, nullable = false)
    private String payStayZone;

    @Column(length = 128)
    private String street;

    @Column(name = "between_street_1", length = 128)
    private String betweenStreet1;

    @Column(name = "between_street_2", length = 128)
    private String betweenStreet2;

    @Column(name = "street_segment_id", nullable = false)
    private Long streetSegmentId;

    // getters/setters
    /**
     * Returns the primary key identifier.
     *
     * @return primary key identifier
     */
    public Long getId() {
        return id;
    }

    /**
     * Sets the primary key identifier.
     *
     * @param id identifier
     */
    public void setId(Long id) {
        this.id = id;
    }

    /**
     * Returns the PayStay zone identifier.
     *
     * @return PayStay zone identifier
     */
    public String getPayStayZone() {
        return payStayZone;
    }

    /**
     * Sets the PayStay zone identifier.
     *
     * @param payStayZone zone identifier
     */
    public void setPayStayZone(String payStayZone) {
        this.payStayZone = payStayZone;
    }

    /**
     * Returns the street name associated with the zone.
     *
     * @return street name associated with the zone
     */
    public String getStreet() {
        return street;
    }

    /**
     * Sets the street name associated with the zone.
     *
     * @param street street name
     */
    public void setStreet(String street) {
        this.street = street;
    }

    /**
     * Returns the first cross street description.
     *
     * @return first cross street description
     */
    public String getBetweenStreet1() {
        return betweenStreet1;
    }

    /**
     * Sets the first cross street description.
     *
     * @param betweenStreet1 cross street
     */
    public void setBetweenStreet1(String betweenStreet1) {
        this.betweenStreet1 = betweenStreet1;
    }

    /**
     * Returns the second cross street description.
     *
     * @return second cross street description
     */
    public String getBetweenStreet2() {
        return betweenStreet2;
    }

    /**
     * Sets the second cross street description.
     *
     * @param betweenStreet2 cross street
     */
    public void setBetweenStreet2(String betweenStreet2) {
        this.betweenStreet2 = betweenStreet2;
    }

    /**
     * Returns the street segment identifier.
     *
     * @return street segment identifier
     */
    public Long getStreetSegmentId() {
        return streetSegmentId;
    }

    /**
     * Sets the street segment identifier.
     *
     * @param streetSegmentId segment identifier
     */
    public void setStreetSegmentId(Long streetSegmentId) {
        this.streetSegmentId = streetSegmentId;
    }
}
