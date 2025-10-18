package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Entity representing a physical parking bay along a street segment.
 */
@Entity
@Table(
        name = "parking_bays",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_bay_seg_kerb",
                columnNames = {"street_segment_id", "kerbside_id"}
        )
)
public class ParkingBay {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "street_segment_id", nullable = false)
    private Long streetSegmentId;

    @Column(name = "kerbside_id")
    private Long kerbsideId;

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

    /**
     * JPA constructor.
     */
    protected ParkingBay() {
    }

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
     * @param id bay identifier
     */
    public void setId(Long id) {
        this.id = id;
    }

    /**
     * Returns the street segment identifier associated with the bay.
     *
     * @return street segment identifier associated with the bay
     */
    public Long getStreetSegmentId() {
        return streetSegmentId;
    }

    /**
     * Sets the street segment identifier associated with the bay.
     *
     * @param streetSegmentId street segment identifier
     */
    public void setStreetSegmentId(Long streetSegmentId) {
        this.streetSegmentId = streetSegmentId;
    }

    /**
     * Returns the kerbside identifier supplied by the source dataset.
     *
     * @return kerbside identifier supplied by the source dataset
     */
    public Long getKerbsideId() {
        return kerbsideId;
    }

    /**
     * Sets the kerbside identifier supplied by the source dataset.
     *
     * @param kerbsideId kerbside identifier
     */
    public void setKerbsideId(Long kerbsideId) {
        this.kerbsideId = kerbsideId;
    }

    /**
     * Returns the descriptive text for the street segment.
     *
     * @return descriptive text for the street segment
     */
    public String getDescription() {
        return description;
    }

    /**
     * Sets the descriptive text for the street segment.
     *
     * @param description street description
     */
    public void setDescription(String description) {
        this.description = description;
    }

    /**
     * Returns the latitude in WGS84 decimal degrees.
     *
     * @return latitude in WGS84 decimal degrees
     */
    public double getLat() {
        return lat;
    }

    /**
     * Sets the latitude in WGS84 decimal degrees.
     *
     * @param lat latitude coordinate
     */
    public void setLat(double lat) {
        this.lat = lat;
    }

    /**
     * Returns the longitude in WGS84 decimal degrees.
     *
     * @return longitude in WGS84 decimal degrees
     */
    public double getLng() {
        return lng;
    }

    /**
     * Sets the longitude in WGS84 decimal degrees.
     *
     * @param lng longitude coordinate
     */
    public void setLng(double lng) {
        this.lng = lng;
    }

    /**
     * Returns the spatial point representing the bay location.
     *
     * @return spatial point representing the bay location
     */
    public Point getLocation() {
        return location;
    }

    /**
     * Sets the spatial point representing the bay location.
     *
     * @param location JTS point
     */
    public void setLocation(Point location) {
        this.location = location;
    }

    /**
     * Returns the timestamp of the last update reported by the source system.
     *
     * @return timestamp of the last update reported by the source system
     */
    public LocalDate getLastUpdated() {
        return lastUpdated;
    }

    /**
     * Sets the timestamp of the last update reported by the source system.
     *
     * @param lastUpdated dataset update timestamp
     */
    public void setLastUpdated(LocalDate lastUpdated) {
        this.lastUpdated = lastUpdated;
    }

    /**
     * Returns the creation timestamp.
     *
     * @return creation timestamp
     */
    public Instant getCreatedAt() {
        return createdAt;
    }

    /**
     * Sets the creation timestamp.
     *
     * @param createdAt creation timestamp
     */
    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    /**
     * Returns the last update timestamp.
     *
     * @return last update timestamp
     */
    public Instant getUpdatedAt() {
        return updatedAt;
    }

    /**
     * Sets the last update timestamp.
     *
     * @param updatedAt last update timestamp
     */
    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
