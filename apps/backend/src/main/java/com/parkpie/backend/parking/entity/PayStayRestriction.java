package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;
import java.time.LocalTime;

@Entity
@Table(
        name = "pay_stay_restrictions",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_zone_day_time",
                columnNames = {"pay_stay_zone","day_of_week","start_time","end_time"}
        )
)
public class PayStayRestriction {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "pay_stay_zone", length = 32, nullable = false)
    private String payStayZone;

    @Column(name = "day_of_week", nullable = false)
    private int dayOfWeek; // 1-7

    @Column(name = "start_time", nullable = false)
    private LocalTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalTime endTime;

    @Column(name = "minimum_stay_minutes")
    private Integer minimumStayMinutes; // nullable per dataset (rare blanks)

    @Column(name = "maximum_stay_minutes", nullable = false)
    private int maximumStayMinutes;

    @Column(name = "cost_per_hour_cents", nullable = false)
    private int costPerHourCents;

    @Column(length = 32)
    private String dayOfWeekName;

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

    public int getDayOfWeek() {
        return dayOfWeek;
    }

    public void setDayOfWeek(int dayOfWeek) {
        this.dayOfWeek = dayOfWeek;
    }

    public LocalTime getStartTime() {
        return startTime;
    }

    public void setStartTime(LocalTime startTime) {
        this.startTime = startTime;
    }

    public LocalTime getEndTime() {
        return endTime;
    }

    public void setEndTime(LocalTime endTime) {
        this.endTime = endTime;
    }

    public Integer getMinimumStayMinutes() {
        return minimumStayMinutes;
    }

    public void setMinimumStayMinutes(Integer minimumStayMinutes) {
        this.minimumStayMinutes = minimumStayMinutes;
    }

    public int getMaximumStayMinutes() {
        return maximumStayMinutes;
    }

    public void setMaximumStayMinutes(int maximumStayMinutes) {
        this.maximumStayMinutes = maximumStayMinutes;
    }

    public int getCostPerHourCents() {
        return costPerHourCents;
    }

    public void setCostPerHourCents(int costPerHourCents) {
        this.costPerHourCents = costPerHourCents;
    }

    public String getDayOfWeekName() {
        return dayOfWeekName;
    }

    public void setDayOfWeekName(String dayOfWeekName) {
        this.dayOfWeekName = dayOfWeekName;
    }
}
