package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "parking_bays")
public class ParkingBay {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long roadSegmentId;

    private Long kerbsideId;

    @Column(length = 500)
    private String description;

    // Redundant lat/lng for convenient projections & debugging
    private double lat;

    private double lng;

    // Geometry
    @Column(columnDefinition = "geometry(Point,4326)")
    @JdbcTypeCode(SqlTypes.GEOMETRY)
    private Point location;

    private LocalDate lastUpdated;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    // getters/setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getRoadSegmentId() {
        return roadSegmentId;
    }

    public void setRoadSegmentId(Long roadSegmentId) {
        this.roadSegmentId = roadSegmentId;
    }

    public Long getKerbsideId() {
        return kerbsideId;
    }

    public void setKerbsideId(Long kerbsideId) {
        this.kerbsideId = kerbsideId;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public double getLat() {
        return lat;
    }

    public void setLat(double lat) {
        this.lat = lat;
    }

    public double getLng() {
        return lng;
    }

    public void setLng(double lng) {
        this.lng = lng;
    }

    public Point getLocation() {
        return location;
    }

    public void setLocation(Point location) {
        this.location = location;
    }

    public LocalDate getLastUpdated() {
        return lastUpdated;
    }

    public void setLastUpdated(LocalDate lastUpdated) {
        this.lastUpdated = lastUpdated;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
