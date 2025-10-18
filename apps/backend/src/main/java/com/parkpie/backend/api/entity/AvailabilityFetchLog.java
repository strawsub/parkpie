package com.parkpie.backend.api.entity;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.persistence.*;

import java.time.LocalDateTime;

/**
 * Entity representing a single execution of the availability fetch job.
 */
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

    /**
     * JPA constructor.
     */
    public AvailabilityFetchLog() {
    }

    /**
     * Returns the unique identifier of the fetch execution.
     *
     * @return execution identifier
     */
    @Schema(description = "Unique identifier of the fetch execution.", example = "1001")
    public Long getId() { return id; }

    /**
     * Sets the unique identifier of the fetch execution.
     *
     * @param id execution identifier
     */
    public void setId(Long id) { this.id = id; }

    /**
     * Returns the origin of the execution (auto, manual, api).
     *
     * @return execution source
     */
    @Schema(description = "Origin of the execution.", example = "manual")
    public String getSource() { return source; }

    /**
     * Sets the origin of the execution (auto, manual, api).
     *
     * @param source execution source
     */
    public void setSource(String source) { this.source = source; }

    /**
     * Returns the start timestamp of the execution.
     *
     * @return start timestamp (UTC)
     */
    @Schema(description = "Timestamp when the job started (UTC).", example = "2025-03-12T08:15:30")
    public LocalDateTime getStartedAt() { return startedAt; }

    /**
     * Sets the start timestamp of the execution.
     *
     * @param startedAt start timestamp (UTC)
     */
    public void setStartedAt(LocalDateTime startedAt) { this.startedAt = startedAt; }

    /**
     * Returns the completion timestamp of the execution.
     *
     * @return completion timestamp (UTC)
     */
    @Schema(description = "Timestamp when the job finished (UTC).", example = "2025-03-12T08:17:04")
    public LocalDateTime getEndedAt() { return endedAt; }

    /**
     * Sets the completion timestamp of the execution.
     *
     * @param endedAt completion timestamp (UTC)
     */
    public void setEndedAt(LocalDateTime endedAt) { this.endedAt = endedAt; }

    /**
     * Returns the number of rows fetched from the upstream source.
     *
     * @return number of fetched rows
     */
    @Schema(description = "Rows fetched from the upstream data source.", example = "325")
    public Integer getRowsFetched() { return rowsFetched; }

    /**
     * Sets the number of rows fetched from the upstream source.
     *
     * @param rowsFetched number of fetched rows
     */
    public void setRowsFetched(Integer rowsFetched) { this.rowsFetched = rowsFetched; }

    /**
     * Returns the number of parking signs upserted during the execution.
     *
     * @return number of upserted signs
     */
    @Schema(description = "Parking signs upserted as part of the execution.", example = "210")
    public Integer getSignsUpserted() { return signsUpserted; }

    /**
     * Sets the number of parking signs upserted during the execution.
     *
     * @param signsUpserted number of upserted signs
     */
    public void setSignsUpserted(Integer signsUpserted) { this.signsUpserted = signsUpserted; }

    /**
     * Returns the execution status (e.g. SUCCESS or ERROR).
     *
     * @return execution status
     */
    @Schema(description = "Execution status.", example = "SUCCESS")
    public String getStatus() { return status; }

    /**
     * Sets the execution status.
     *
     * @param status execution status
     */
    public void setStatus(String status) { this.status = status; }

    /**
     * Returns the informational status message.
     *
     * @return status message
     */
    @Schema(description = "Informational message.", example = "Completed without warnings.")
    public String getMessage() { return message; }

    /**
     * Sets the informational status message.
     *
     * @param message status message
     */
    public void setMessage(String message) { this.message = message; }

    /**
     * Returns the error message if the execution failed.
     *
     * @return error message or {@code null}
     */
    @Schema(description = "Error details when status is ERROR.", example = "Timeout while contacting upstream API.")
    public String getError() { return error; }

    /**
     * Sets the error message for failed executions.
     *
     * @param error error message
     */
    public void setError(String error) { this.error = error; }
}
