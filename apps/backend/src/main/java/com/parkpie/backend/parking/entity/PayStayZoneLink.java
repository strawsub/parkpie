package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "pay_stay_zone_links")
public class PayStayZoneLink {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 32, nullable = false)
    private String payStayZone;

    @Column(length = 128)
    private String street;

    @Column(length = 128)
    private String betweenStreet1;

    @Column(length = 128)
    private String betweenStreet2;

    private Long streetSegmentId;

    // getters/setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getPayStayZone() {
        return payStayZone;
    }

    public void setPayStayZone(String payStayZone) {
        this.payStayZone = payStayZone;
    }

    public String getStreet() {
        return street;
    }

    public void setStreet(String street) {
        this.street = street;
    }

    public String getBetweenStreet1() {
        return betweenStreet1;
    }

    public void setBetweenStreet1(String betweenStreet1) {
        this.betweenStreet1 = betweenStreet1;
    }

    public String getBetweenStreet2() {
        return betweenStreet2;
    }

    public void setBetweenStreet2(String betweenStreet2) {
        this.betweenStreet2 = betweenStreet2;
    }

    public Long getStreetSegmentId() {
        return streetSegmentId;
    }

    public void setStreetSegmentId(Long streetSegmentId) {
        this.streetSegmentId = streetSegmentId;
    }
}
