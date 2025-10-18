package com.parkpie.backend.admin.service;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

/**
 * Manages in-memory progress tracking for long-running administrative uploads.
 */
@Service
public class UploadProgressService {
    
    private final Map<String, UploadProgress> progressMap = new ConcurrentHashMap<>();

    /**
     * Creates the upload progress service.
     */
    public UploadProgressService() {
    }
    
    /**
     * Immutable-style payload representing the state of an asynchronous upload.
     */
    public static class UploadProgress {

        private String id;
        private int currentStage;
        private int totalStages;
        private String currentStageName;
        private int progressPercentage;
        private String status; // "processing", "completed", "error"
        private String message;
        
        /**
         * Creates a new progress tracker with sensible defaults.
         *
         * @param id identifier that correlates progress updates
         */
        public UploadProgress(String id) {
            this.id = id;
            this.currentStage = 0;
            this.totalStages = 4;
            this.currentStageName = "Initializing...";
            this.progressPercentage = 0;
            this.status = "processing";
            this.message = "";
        }
        
        /**
         * Updates the active stage and percentage of an upload.
         *
         * @param stage stage index
         * @param stageName human readable description for the stage
         * @param percentage percent completion for the upload
         */
        public void updateProgress(int stage, String stageName, int percentage) {
            this.currentStage = stage;
            this.currentStageName = stageName;
            this.progressPercentage = percentage;
        }
        
        /**
         * Marks the upload as completed and captures a final message.
         *
         * @param message completion message
         */
        public void complete(String message) {
            this.status = "completed";
            this.progressPercentage = 100;
            this.currentStageName = "Completed";
            this.message = message;
        }
        
        /**
         * Marks the upload as failed and stores the error message.
         *
         * @param message descriptive error message
         */
        public void error(String message) {
            this.status = "error";
            this.message = message;
        }

        // Getters and setters
        /**
         * @return progress identifier
         */
        public String getId() {
            return id;
        }

        /**
         * Sets the progress identifier.
         *
         * @param id new identifier
         */
        public void setId(String id) {
            this.id = id;
        }

        /**
         * @return current stage index
         */
        public int getCurrentStage() {
            return currentStage;
        }

        /**
         * Updates the current stage index.
         *
         * @param currentStage new stage index
         */
        public void setCurrentStage(int currentStage) {
            this.currentStage = currentStage;
        }

        /**
         * @return total number of stages
         */
        public int getTotalStages() {
            return totalStages;
        }

        /**
         * Sets the total number of stages in the upload.
         *
         * @param totalStages total stages
         */
        public void setTotalStages(int totalStages) {
            this.totalStages = totalStages;
        }

        /**
         * @return descriptive name of the current stage
         */
        public String getCurrentStageName() {
            return currentStageName;
        }

        /**
         * Updates the descriptive name of the current stage.
         *
         * @param currentStageName stage description
         */
        public void setCurrentStageName(String currentStageName) {
            this.currentStageName = currentStageName;
        }

        /**
         * @return overall progress percentage
         */
        public int getProgressPercentage() {
            return progressPercentage;
        }

        /**
         * Sets the overall progress percentage.
         *
         * @param progressPercentage percent completion
         */
        public void setProgressPercentage(int progressPercentage) {
            this.progressPercentage = progressPercentage;
        }

        /**
         * @return current upload status
         */
        public String getStatus() {
            return status;
        }

        /**
         * Updates current upload status.
         *
         * @param status new status string
         */
        public void setStatus(String status) {
            this.status = status;
        }

        /**
         * @return optional status message
         */
        public String getMessage() {
            return message;
        }

        /**
         * Sets the optional status message.
         *
         * @param message message describing the state
         */
        public void setMessage(String message) {
            this.message = message;
        }
    }

    /**
     * Initialises progress tracking for a known identifier.
     *
     * @param id identifier to register
     */
    public void initProgress(String id) {
        progressMap.computeIfAbsent(id, UploadProgress::new);
    }

    /**
     * Creates a new progress tracker using a randomly generated identifier.
     *
     * @return generated progress identifier
     */
    public String createProgress() {
        String id = UUID.randomUUID().toString();
        progressMap.put(id, new UploadProgress(id));
        return id;
    }

    /**
     * Creates a new progress tracker using the supplied identifier if one does not already exist.
     *
     * @param id identifier to use
     */
    public void createProgress(String id) {
        progressMap.putIfAbsent(id, new UploadProgress(id));
    }
    
    /**
     * Retrieves progress by identifier.
     *
     * @param id progress identifier
     * @return progress payload or {@code null} if not found
     */
    public UploadProgress getProgress(String id) {
        return progressMap.get(id);
    }

    /**
     * Updates the progress details for an upload.
     *
     * @param id progress identifier
     * @param stage stage index
     * @param stageName stage description
     * @param percentage completion percentage
     */
    public void updateProgress(String id, int stage, String stageName, int percentage) {
        progressMap.computeIfAbsent(id, UploadProgress::new).updateProgress(stage, stageName, percentage);
    }

    /**
     * Marks an upload as completed.
     *
     * @param id progress identifier
     * @param message completion message
     */
    public void completeProgress(String id, String message) {
        progressMap.computeIfAbsent(id, UploadProgress::new).complete(message);
    }

    /**
     * Marks an upload as failed.
     *
     * @param id progress identifier
     * @param message error message describing the failure
     */
    public void errorProgress(String id, String message) {
        progressMap.computeIfAbsent(id, UploadProgress::new).error(message);
    }

    /**
     * Removes an upload from the progress map.
     *
     * @param id progress identifier
     */
    public void removeProgress(String id) {
        progressMap.remove(id);
    }
}
