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
@Table(
        name = "parking_bays",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_bay_natkey",
                columnNames = {"street_segment_id", "kerbside_id", "lat", "lng"}
        )
)
public class ParkingBay {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "street_segment_id", nullable = false)
    private Long streetSegmentId;

    @Column(name = "kerbside_id", nullable = false)
    private long kerbsideId;

    @Column(length = 500)
    private String description;

    private double lat;

    private double lng;

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

    public Long getStreetSegmentId() {
        return streetSegmentId;
    }

    public void setStreetSegmentId(Long streetSegmentId) {
        this.streetSegmentId = streetSegmentId;
    }

    public long getKerbsideId() {
        return kerbsideId;
    }

    public void setKerbsideId(long kerbsideId) {
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
