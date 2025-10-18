package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

/**
 * Realtime occupancy per Kerbside bay.
 *
 * Backed by table "parking_bay_realtime" which is expected to contain one row per kerbsideid.
 * Columns used here mirror the live feed: lastupdated, status_timestamp, status_description, kerbsideid.
 */
/**
 * Entity representing realtime occupancy data for a single kerbside bay.
 */
@Entity
@Table(name = "parking_bay_realtime")
public class ParkingBayRealtime {

    @Id
    @Column(name = "kerbsideid")
    private Long kerbsideId;

    @Column(name = "lastupdated", nullable = false)
    private LocalDateTime lastUpdated;

    @Column(name = "status_timestamp", nullable = false)
    private LocalDateTime statusTimestamp;

    // Stored in Postgres enum type occupancy_status; persisted via native queries with ::occupancy_status cast
    @Column(name = "status_description", nullable = false)
    private String statusDescription; // values: "Present" or "Unoccupied"

    @Column(name = "zone_number")
    private Integer zoneNumber; // nullable

    /**
     * JPA constructor.
     */
    protected ParkingBayRealtime() {
    }

    /**
     * Returns the unique kerbside identifier.
     *
     * @return unique kerbside identifier
     */
    public Long getKerbsideId() {
        return kerbsideId;
    }

    /**
     * Sets the unique kerbside identifier.
     *
     * @param kerbsideId kerbside identifier
     */
    public void setKerbsideId(Long kerbsideId) {
        this.kerbsideId = kerbsideId;
    }

    /**
     * Returns the timestamp the upstream data feed last updated the row.
     *
     * @return timestamp the upstream data feed last updated the row
     */
    public LocalDateTime getLastUpdated() {
        return lastUpdated;
    }

    /**
     * Sets the timestamp the upstream data feed last updated the row.
     *
     * @param lastUpdated update timestamp
     */
    public void setLastUpdated(LocalDateTime lastUpdated) {
        this.lastUpdated = lastUpdated;
    }

    /**
     * Returns the timestamp at which the occupancy status was observed.
     *
     * @return timestamp at which the occupancy status was observed
     */
    public LocalDateTime getStatusTimestamp() {
        return statusTimestamp;
    }

    /**
     * Sets the timestamp at which the occupancy status was observed.
     *
     * @param statusTimestamp status observation timestamp
     */
    public void setStatusTimestamp(LocalDateTime statusTimestamp) {
        this.statusTimestamp = statusTimestamp;
    }

    /**
     * Returns the occupancy status description.
     *
     * @return occupancy status description, e.g. {@code Present} or {@code Unoccupied}
     */
    public String getStatusDescription() {
        return statusDescription;
    }

    /**
     * Sets the occupancy status description.
     *
     * @param statusDescription occupancy status
     */
    public void setStatusDescription(String statusDescription) {
        this.statusDescription = statusDescription;
    }

    /**
     * Returns the zone associated with the bay, when available.
     *
     * @return zone associated with the bay, when available
     */
    public Integer getZoneNumber() {
        return zoneNumber;
    }

    /**
     * Sets the zone associated with the bay.
     *
     * @param zoneNumber zone number
     */
    public void setZoneNumber(Integer zoneNumber) {
        this.zoneNumber = zoneNumber;
    }
}
