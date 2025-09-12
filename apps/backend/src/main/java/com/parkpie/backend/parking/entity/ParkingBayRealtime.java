package com.parkpie.backend.parking.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

/**
 * Realtime occupancy per Kerbside bay.
 *
 * Backed by table "parking_bay_realtime" which is expected to contain one row per kerbsideid.
 * Columns used here mirror the live feed: lastupdated, status_timestamp, status_description, kerbsideid.
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

    public Long getKerbsideId() {
        return kerbsideId;
    }

    public void setKerbsideId(Long kerbsideId) {
        this.kerbsideId = kerbsideId;
    }

    public LocalDateTime getLastUpdated() {
        return lastUpdated;
    }

    public void setLastUpdated(LocalDateTime lastUpdated) {
        this.lastUpdated = lastUpdated;
    }

    public LocalDateTime getStatusTimestamp() {
        return statusTimestamp;
    }

    public void setStatusTimestamp(LocalDateTime statusTimestamp) {
        this.statusTimestamp = statusTimestamp;
    }

    public String getStatusDescription() {
        return statusDescription;
    }

    public void setStatusDescription(String statusDescription) {
        this.statusDescription = statusDescription;
    }

    public Integer getZoneNumber() {
        return zoneNumber;
    }

    public void setZoneNumber(Integer zoneNumber) {
        this.zoneNumber = zoneNumber;
    }
}
