package com.parkpie.backend.admin.service;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

@Service
public class UploadProgressService {
    
    private final Map<String, UploadProgress> progressMap = new ConcurrentHashMap<>();
    
    public static class UploadProgress {

        private String id;
        private int currentStage;
        private int totalStages;
        private String currentStageName;
        private int progressPercentage;
        private String status; // "processing", "completed", "error"
        private String message;
        
        public UploadProgress(String id) {
            this.id = id;
            this.currentStage = 0;
            this.totalStages = 4;
            this.currentStageName = "Initializing...";
            this.progressPercentage = 0;
            this.status = "processing";
            this.message = "";
        }
        
        public void updateProgress(int stage, String stageName, int percentage) {
            this.currentStage = stage;
            this.currentStageName = stageName;
            this.progressPercentage = percentage;
        }
        
        public void complete(String message) {
            this.status = "completed";
            this.progressPercentage = 100;
            this.currentStageName = "Completed";
            this.message = message;
        }
        
        public void error(String message) {
            this.status = "error";
            this.message = message;
        }

        // Getters and setters
        public String getId() {
            return id;
        }

        public void setId(String id) {
            this.id = id;
        }

        public int getCurrentStage() {
            return currentStage;
        }

        public void setCurrentStage(int currentStage) {
            this.currentStage = currentStage;
        }

        public int getTotalStages() {
            return totalStages;
        }

        public void setTotalStages(int totalStages) {
            this.totalStages = totalStages;
        }

        public String getCurrentStageName() {
            return currentStageName;
        }

        public void setCurrentStageName(String currentStageName) {
            this.currentStageName = currentStageName;
        }

        public int getProgressPercentage() {
            return progressPercentage;
        }

        public void setProgressPercentage(int progressPercentage) {
            this.progressPercentage = progressPercentage;
        }

        public String getStatus() {
            return status;
        }

        public void setStatus(String status) {
            this.status = status;
        }

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }
    }

    public void initProgress(String id) {
        progressMap.computeIfAbsent(id, UploadProgress::new);
    }

    public String createProgress() {
        String id = UUID.randomUUID().toString();
        progressMap.put(id, new UploadProgress(id));
        return id;
    }

    public void createProgress(String id) {
        progressMap.putIfAbsent(id, new UploadProgress(id));
    }
    
    public UploadProgress getProgress(String id) {
        return progressMap.get(id);
    }

    public void updateProgress(String id, int stage, String stageName, int percentage) {
        progressMap.computeIfAbsent(id, UploadProgress::new).updateProgress(stage, stageName, percentage);
    }

    public void completeProgress(String id, String message) {
        progressMap.computeIfAbsent(id, UploadProgress::new).complete(message);
    }

    public void errorProgress(String id, String message) {
        progressMap.computeIfAbsent(id, UploadProgress::new).error(message);
    }

    public void removeProgress(String id) {
        progressMap.remove(id);
    }
}
