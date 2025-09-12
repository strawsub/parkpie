package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

import java.time.LocalTime;

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

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Integer getZoneNumber() { return zoneNumber; }
    public void setZoneNumber(Integer zoneNumber) { this.zoneNumber = zoneNumber; }


    public Point getLocation() { return location; }
    public void setLocation(Point location) { this.location = location; }

    public Integer getDayOfWeek() { return dayOfWeek; }
    public void setDayOfWeek(Integer dayOfWeek) { this.dayOfWeek = dayOfWeek; }

    public LocalTime getStartTime() { return startTime; }
    public void setStartTime(LocalTime startTime) { this.startTime = startTime; }

    public LocalTime getEndTime() { return endTime; }
    public void setEndTime(LocalTime endTime) { this.endTime = endTime; }

    public Integer getMaximumStayMinutes() { return maximumStayMinutes; }
    public void setMaximumStayMinutes(Integer maximumStayMinutes) { this.maximumStayMinutes = maximumStayMinutes; }

    public Double getOccupancyPercent() { return occupancyPercent; }
    public void setOccupancyPercent(Double occupancyPercent) { this.occupancyPercent = occupancyPercent; }

    public java.time.LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(java.time.LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
