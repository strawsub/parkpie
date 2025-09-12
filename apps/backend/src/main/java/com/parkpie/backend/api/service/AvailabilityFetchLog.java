package com.parkpie.backend.api.service;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "availability_fetch_log")
public class AvailabilityFetchLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 32)
    private String source; // auto, manual, api

    private LocalDateTime startedAt;

    private LocalDateTime endedAt;

    private Integer rowsFetched;

    private Integer signsUpserted;

    @Column(length = 32)
    private String status; // SUCCESS / ERROR

    @Column(length = 4000)
    private String message;

    @Column(length = 4000)
    private String error;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public LocalDateTime getStartedAt() { return startedAt; }
    public void setStartedAt(LocalDateTime startedAt) { this.startedAt = startedAt; }
    public LocalDateTime getEndedAt() { return endedAt; }
    public void setEndedAt(LocalDateTime endedAt) { this.endedAt = endedAt; }
    public Integer getRowsFetched() { return rowsFetched; }
    public void setRowsFetched(Integer rowsFetched) { this.rowsFetched = rowsFetched; }
    public Integer getSignsUpserted() { return signsUpserted; }
    public void setSignsUpserted(Integer signsUpserted) { this.signsUpserted = signsUpserted; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
    public String getError() { return error; }
    public void setError(String error) { this.error = error; }
}
