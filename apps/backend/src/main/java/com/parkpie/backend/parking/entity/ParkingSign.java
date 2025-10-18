package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.LocalTime;

/**
 * Entity representing a parking restriction window associated with a zone.
 */
@Entity
@Table(name = "parking_signs",
       uniqueConstraints = @UniqueConstraint(name = "uq_sign_zone_window",
               columnNames = {"zone_number","day_of_week","start_time","end_time"}))
public class ParkingSign {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Derived attributes
    @Column(name = "zone_number")
    private Integer zoneNumber; // from parking_bay_realtime.zone_number

    // bay_count removed; rely on occupancy_percent + geometry

    // Pin location for frontend
    @Column(columnDefinition = "geometry(Point,4326)")
    @JdbcTypeCode(SqlTypes.GEOMETRY)
    private Point location;

    // Restriction details (copied from pay_stay_restrictions)
    @Column(name = "day_of_week")
    private Integer dayOfWeek;

    @Column(name = "start_time")
    private LocalTime startTime;

    @Column(name = "end_time")
    private LocalTime endTime;

    @Column(name = "maximum_stay_minutes")
    private Integer maximumStayMinutes;

    // Percentage (0..1) of bays with Present status in this zone
    @Column(name = "occupancy_percent")
    private Double occupancyPercent;

    // Reflects realtime lastupdated (MAX per zone)
    @Column(name = "updated_at")
    private java.time.LocalDateTime updatedAt;

    /**
     * JPA constructor.
     */
    public ParkingSign() {
    }

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
     * Returns the zone number associated with the restriction.
     *
     * @return zone number associated with the restriction
     */
    public Integer getZoneNumber() {
        return zoneNumber;
    }

    /**
     * Sets the zone number associated with the restriction.
     *
     * @param zoneNumber zone identifier
     */
    public void setZoneNumber(Integer zoneNumber) {
        this.zoneNumber = zoneNumber;
    }

    /**
     * Returns the representative point for the restriction geometry.
     *
     * @return representative point for the restriction geometry
     */
    public Point getLocation() {
        return location;
    }

    /**
     * Sets the representative point for the restriction geometry.
     *
     * @param location geometry point
     */
    public void setLocation(Point location) {
        this.location = location;
    }

    /**
     * Returns the ISO day-of-week (1-7) for the restriction window.
     *
     * @return ISO day-of-week (1-7) for the restriction window
     */
    public Integer getDayOfWeek() {
        return dayOfWeek;
    }

    /**
     * Sets the ISO day-of-week (1-7) for the restriction window.
     *
     * @param dayOfWeek day of week
     */
    public void setDayOfWeek(Integer dayOfWeek) {
        this.dayOfWeek = dayOfWeek;
    }

    /**
     * Returns the restriction start time.
     *
     * @return restriction start time
     */
    public LocalTime getStartTime() {
        return startTime;
    }

    /**
     * Sets the restriction start time.
     *
     * @param startTime start time
     */
    public void setStartTime(LocalTime startTime) {
        this.startTime = startTime;
    }

    /**
     * Returns the restriction end time.
     *
     * @return restriction end time
     */
    public LocalTime getEndTime() {
        return endTime;
    }

    /**
     * Sets the restriction end time.
     *
     * @param endTime end time
     */
    public void setEndTime(LocalTime endTime) {
        this.endTime = endTime;
    }

    /**
     * Returns the maximum stay in minutes, when defined.
     *
     * @return maximum stay in minutes, when defined
     */
    public Integer getMaximumStayMinutes() {
        return maximumStayMinutes;
    }

    /**
     * Sets the maximum stay in minutes.
     *
     * @param maximumStayMinutes maximum stay duration
     */
    public void setMaximumStayMinutes(Integer maximumStayMinutes) {
        this.maximumStayMinutes = maximumStayMinutes;
    }

    /**
     * Returns the occupancy percentage for the zone.
     *
     * @return occupancy percentage for the zone
     */
    public Double getOccupancyPercent() {
        return occupancyPercent;
    }

    /**
     * Sets the occupancy percentage for the zone.
     *
     * @param occupancyPercent percentage of occupied bays
     */
    public void setOccupancyPercent(Double occupancyPercent) {
        this.occupancyPercent = occupancyPercent;
    }

    /**
     * Returns the timestamp of the last occupancy update.
     *
     * @return timestamp of the last occupancy update
     */
    public java.time.LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    /**
     * Sets the timestamp of the last occupancy update.
     *
     * @param updatedAt update timestamp
     */
    public void setUpdatedAt(java.time.LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
