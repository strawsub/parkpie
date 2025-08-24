package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;

import java.time.LocalTime;

@Entity
@Table(name = "pay_stay_restrictions")
public class PayStayRestriction {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 32, nullable = false)
    private String payStayZone;

    private int dayOfWeek; // 1-7

    private LocalTime startTime;

    private LocalTime endTime;

    // minutes
    private int minimumStayMinutes;

    private int maximumStayMinutes;

    // cents per hour
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

    public int getMinimumStayMinutes() {
        return minimumStayMinutes;
    }

    public void setMinimumStayMinutes(int minimumStayMinutes) {
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
