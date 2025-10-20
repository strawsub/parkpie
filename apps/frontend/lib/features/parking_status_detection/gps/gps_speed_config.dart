class GpsSpeedConfig {
  // Speed thresholds in m/s (hysteresis) - scenario-based
  final double vInGood;   // Enter parking (good GPS)
  final double vInMedium; // Enter parking (medium GPS)
  final double vInPoor;   // Enter parking (poor GPS)
  final double vOutGood;  // Exit parking (good GPS)
  final double vOutMedium; // Exit parking (medium GPS)
  final double vOutPoor;  // Exit parking (poor GPS)

  // Time thresholds in seconds - scenario-based
  final double tCandidateGood;  // Driving confirmation time (good GPS)
  final double tCandidateMedium; // Driving confirmation time (medium GPS)
  final double tCandidatePoor;  // Driving confirmation time (poor GPS)
  final double tConfirmGood;    // Parking confirmation time (good GPS)
  final double tConfirmMedium;  // Parking confirmation time (medium GPS)
  final double tConfirmPoor;    // Parking confirmation time (poor GPS)

  // Distance thresholds in meters - scenario-based
  final double dWindowGood;   // Displacement window (good GPS)
  final double dWindowMedium; // Displacement window (medium GPS)
  final double dWindowPoor;   // Displacement window (poor GPS)
  final double dDrivingThreshold; // Linear distance for driving confirmation (15 meters)

  // GPS accuracy thresholds in meters
  final double maxAccuracyThreshold; // Reject GPS readings worse than this (relaxed during cold start)
  final double goodAccuracyThreshold; // Threshold for "good" GPS scenario
  final double mediumAccuracyThreshold; // Threshold for "medium" GPS scenario

  // Zero-speed detection (stationary phone)
  final double zeroSpeedThreshold; // Force speed to 0 if below this: 0.5 m/s (~1.8 km/h)
  final double zeroSpeedAccuracyThreshold; // Only apply zero-speed if accuracy worse than: 20m

  // Accuracy weighting parameters
  final double accuracyWeightThreshold; // Accuracy above this reduces sample weight
  final double minSampleWeight; // Minimum weight for poor accuracy samples (0-1)

  // Sampling strategy parameters
  final double initializationDuration; // Seconds of dense sampling after app start
  final int distanceFilterInitialization; // Distance filter during initialization (meters)
  final int distanceFilterNormal; // Distance filter after initialization (meters)
  final double minUpdateInterval; // Minimum seconds between updates for timer progress

  const GpsSpeedConfig({
    // Unified speed threshold: 10 km/h (2.78 m/s) for all scenarios
    this.vInGood = 2.78,                  // 2.78 m/s (10 km/h) - good GPS
    this.vInMedium = 2.78,                // 2.78 m/s (10 km/h) - medium GPS
    this.vInPoor = 2.78,                  // 2.78 m/s (10 km/h) - poor GPS
    this.vOutGood = 2.78,                 // 2.78 m/s (10 km/h) - good GPS
    this.vOutMedium = 2.78,               // 2.78 m/s (10 km/h) - medium GPS
    this.vOutPoor = 2.78,                 // 2.78 m/s (10 km/h) - poor GPS

    // Scenario-based time thresholds
    this.tCandidateGood = 10.0,           // 10.0 seconds - good GPS (increased for stricter driving detection)
    this.tCandidateMedium = 10.0,         // 10.0 seconds - medium GPS
    this.tCandidatePoor = 10.0,           // 10.0 seconds - poor GPS
    this.tConfirmGood = 4.0,              // 4.0 seconds - good GPS (reduced from 5)
    this.tConfirmMedium = 5.0,            // 5.0 seconds - medium GPS
    this.tConfirmPoor = 6.0,              // 6.0 seconds - poor GPS (increased for stability)

    // Scenario-based displacement thresholds
    this.dWindowGood = 12.0,              // 12.0 meters - good GPS (widened from 8)
    this.dWindowMedium = 16.0,            // 16.0 meters - medium GPS (widened from 10)
    this.dWindowPoor = 20.0,              // 20.0 meters - poor GPS (widened from 15)
    this.dDrivingThreshold = 20.0,        // 20.0 meters - linear distance for driving confirmation (increased from 10.0)

    // GPS accuracy scenario boundaries
    this.maxAccuracyThreshold = 50.0,     // 50 meters - relaxed for cold start
    this.goodAccuracyThreshold = 10.0,    // ≤10m = good GPS
    this.mediumAccuracyThreshold = 20.0,  // 10-20m = medium GPS, >20m = poor GPS

    // Zero-speed detection (GPS drift suppression)
    this.zeroSpeedThreshold = 0.5,        // Force to 0 if speed <0.5 m/s (~1.8 km/h)
    this.zeroSpeedAccuracyThreshold = 20.0, // Only apply if accuracy >20m (poor GPS)

    // Accuracy weighting
    this.accuracyWeightThreshold = 15.0,  // Start reducing weight above 15m accuracy
    this.minSampleWeight = 0.3,           // Minimum 30% weight for poor samples

    // Sampling strategy
    this.initializationDuration = 15.0,   // 15 seconds of dense sampling
    this.distanceFilterInitialization = 0, // No distance filter during init (max density)
    this.distanceFilterNormal = 1,        // 1 meter after initialization
    this.minUpdateInterval = 0.5,         // Minimum 0.5s between updates (faster UI response)
  });
}
