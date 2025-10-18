package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;
import java.time.LocalTime;

/**
 * Entity representing a PayStay restriction window for a zone.
 */
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
     * Returns the ISO day-of-week value (1-7).
     *
     * @return ISO day-of-week value (1-7)
     */
    public int getDayOfWeek() {
        return dayOfWeek;
    }

    /**
     * Sets the ISO day-of-week value (1-7).
     *
     * @param dayOfWeek day of week
     */
    public void setDayOfWeek(int dayOfWeek) {
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
     * Returns the minimum stay minutes, if defined.
     *
     * @return minimum stay minutes, if defined
     */
    public Integer getMinimumStayMinutes() {
        return minimumStayMinutes;
    }

    /**
     * Sets the minimum stay minutes.
     *
     * @param minimumStayMinutes minimum stay
     */
    public void setMinimumStayMinutes(Integer minimumStayMinutes) {
        this.minimumStayMinutes = minimumStayMinutes;
    }

    /**
     * Returns the maximum stay minutes.
     *
     * @return maximum stay minutes
     */
    public int getMaximumStayMinutes() {
        return maximumStayMinutes;
    }

    /**
     * Sets the maximum stay minutes.
     *
     * @param maximumStayMinutes maximum stay
     */
    public void setMaximumStayMinutes(int maximumStayMinutes) {
        this.maximumStayMinutes = maximumStayMinutes;
    }

    /**
     * Returns the cost per hour in cents.
     *
     * @return cost per hour in cents
     */
    public int getCostPerHourCents() {
        return costPerHourCents;
    }

    /**
     * Sets the cost per hour in cents.
     *
     * @param costPerHourCents hourly cost
     */
    public void setCostPerHourCents(int costPerHourCents) {
        this.costPerHourCents = costPerHourCents;
    }

    /**
     * Returns the textual day-of-week label, when provided.
     *
     * @return textual day-of-week label, when provided
     */
    public String getDayOfWeekName() {
        return dayOfWeekName;
    }

    /**
     * Sets the textual day-of-week label.
     *
     * @param dayOfWeekName day name
     */
    public void setDayOfWeekName(String dayOfWeekName) {
        this.dayOfWeekName = dayOfWeekName;
    }
}
