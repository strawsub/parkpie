package com.parkpie.backend.api.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "availability_fetch_log")
@Schema(description = "Execution metadata for a parking availability fetch job.")
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

    @Schema(description = "Unique identifier of the fetch execution.", example = "1001")
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    @Schema(description = "Origin of the execution.", example = "manual")
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    @Schema(description = "Timestamp when the job started (UTC).", example = "2025-03-12T08:15:30")
    public LocalDateTime getStartedAt() { return startedAt; }
    public void setStartedAt(LocalDateTime startedAt) { this.startedAt = startedAt; }
    @Schema(description = "Timestamp when the job finished (UTC).", example = "2025-03-12T08:17:04")
    public LocalDateTime getEndedAt() { return endedAt; }
    public void setEndedAt(LocalDateTime endedAt) { this.endedAt = endedAt; }
    @Schema(description = "Rows fetched from the upstream data source.", example = "325")
    public Integer getRowsFetched() { return rowsFetched; }
    public void setRowsFetched(Integer rowsFetched) { this.rowsFetched = rowsFetched; }
    @Schema(description = "Parking signs upserted as part of the execution.", example = "210")
    public Integer getSignsUpserted() { return signsUpserted; }
    public void setSignsUpserted(Integer signsUpserted) { this.signsUpserted = signsUpserted; }
    @Schema(description = "Execution status.", example = "SUCCESS")
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    @Schema(description = "Informational message.", example = "Completed without warnings.")
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }
    @Schema(description = "Error details when status is ERROR.", example = "Timeout while contacting upstream API.")
    public String getError() { return error; }
    public void setError(String error) { this.error = error; }
}
