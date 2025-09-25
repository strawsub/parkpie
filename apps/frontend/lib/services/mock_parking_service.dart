import '../features/map/pin/pin_model.dart';

/// Mock service to simulate multiple restrictions per day for UI testing
/// This simulates the enhanced API that will return multiple time periods per day
class MockParkingService {

  /// Sample Melbourne parking location with realistic multi-restriction data
  static ParkingLocation getMockParkingLocation() {
    return ParkingLocation(
      lat: -37.8481,
      lng: 144.9831,
      description: "Flinders Street between Elizabeth Street and Queen Street",
      restrictions: _generateMockRestrictions(),
    );
  }

  /// Generate realistic parking restrictions based on Melbourne CBD patterns
  static List<ParkingRestriction> _generateMockRestrictions() {
    return [
      // MONDAY - 2 restrictions
      ParkingRestriction(
        id: "mock_1_1",
        dayOfWeek: 1, // Monday
        startTime: "07:30:00",
        endTime: "20:00:00", // 8 PM
        maximumStayMinutes: 120, // 2 hours
        occupancyPercent: 0.77, // 77% occupancy
      ),
      ParkingRestriction(
        id: "mock_1_2",
        dayOfWeek: 1, // Monday
        startTime: "20:00:00",
        endTime: "07:00:00", // Overnight to 7 AM next day
        maximumStayMinutes: 150, // 2.5 hours
        occupancyPercent: 0.77, // Same occupancy for current day
      ),

      // TUESDAY - 3 restrictions
      ParkingRestriction(
        id: "mock_2_1",
        dayOfWeek: 2, // Tuesday
        startTime: "08:00:00",
        endTime: "12:00:00", // Morning period
        maximumStayMinutes: 60, // 1 hour
        occupancyPercent: 0.65,
      ),
      ParkingRestriction(
        id: "mock_2_2",
        dayOfWeek: 2, // Tuesday
        startTime: "12:00:00",
        endTime: "18:00:00", // Afternoon period
        maximumStayMinutes: 90, // 1.5 hours
        occupancyPercent: 0.65,
      ),
      ParkingRestriction(
        id: "mock_2_3",
        dayOfWeek: 2, // Tuesday
        startTime: "18:00:00",
        endTime: "22:00:00", // Evening period
        maximumStayMinutes: 240, // 4 hours
        occupancyPercent: 0.65,
      ),

      // WEDNESDAY - 1 restriction
      ParkingRestriction(
        id: "mock_3_1",
        dayOfWeek: 3, // Wednesday
        startTime: "09:00:00",
        endTime: "17:00:00", // 9-5 workday
        maximumStayMinutes: 180, // 3 hours
        occupancyPercent: 0.82,
      ),

      // THURSDAY - 2 restrictions
      ParkingRestriction(
        id: "mock_4_1",
        dayOfWeek: 4, // Thursday
        startTime: "07:00:00",
        endTime: "16:00:00", // Day period
        maximumStayMinutes: 120, // 2 hours
        occupancyPercent: 0.71,
      ),
      ParkingRestriction(
        id: "mock_4_2",
        dayOfWeek: 4, // Thursday
        startTime: "16:00:00",
        endTime: "23:00:00", // Evening period
        maximumStayMinutes: 300, // 5 hours
        occupancyPercent: 0.71,
      ),

      // FRIDAY - 2 restrictions
      ParkingRestriction(
        id: "mock_5_1",
        dayOfWeek: 5, // Friday
        startTime: "08:00:00",
        endTime: "18:00:00", // Business hours
        maximumStayMinutes: 90, // 1.5 hours
        occupancyPercent: 0.89, // High Friday occupancy
      ),
      ParkingRestriction(
        id: "mock_5_2",
        dayOfWeek: 5, // Friday
        startTime: "18:00:00",
        endTime: "02:00:00", // Friday night
        maximumStayMinutes: 480, // 8 hours
        occupancyPercent: 0.89,
      ),

      // SATURDAY - 3 restrictions
      ParkingRestriction(
        id: "mock_6_1",
        dayOfWeek: 6, // Saturday
        startTime: "06:00:00",
        endTime: "13:00:00", // Morning/early afternoon
        maximumStayMinutes: 30, // Short stay
        occupancyPercent: null, // Future day - unknown occupancy
      ),
      ParkingRestriction(
        id: "mock_6_2",
        dayOfWeek: 6, // Saturday
        startTime: "13:00:00",
        endTime: "20:00:00", // Afternoon/evening
        maximumStayMinutes: 45, // Short stay
        occupancyPercent: null,
      ),
      ParkingRestriction(
        id: "mock_6_3",
        dayOfWeek: 6, // Saturday
        startTime: "20:00:00",
        endTime: "02:00:00", // Saturday night
        maximumStayMinutes: 360, // 6 hours
        occupancyPercent: null,
      ),

      // SUNDAY - 1 restriction
      ParkingRestriction(
        id: "mock_7_1",
        dayOfWeek: 7, // Sunday
        startTime: "10:00:00",
        endTime: "22:00:00", // Relaxed Sunday hours
        maximumStayMinutes: 240, // 4 hours
        occupancyPercent: null, // Future day - unknown occupancy
      ),
    ];
  }

  /// Get additional sample locations for testing various scenarios
  static List<ParkingLocation> getMockParkingLocations() {
    return [
      getMockParkingLocation(),

      // Location 2: Different pattern
      ParkingLocation(
        lat: -37.8136,
        lng: 144.9631,
        description: "Collins Street between Swanston Street and Elizabeth Street",
        restrictions: [
          // Weekdays only - no weekend restrictions
          for (int day = 1; day <= 5; day++)
            ParkingRestriction(
              id: "mock_loc2_$day",
              dayOfWeek: day,
              startTime: "08:30:00",
              endTime: "17:30:00",
              maximumStayMinutes: 60, // 1 hour max
              occupancyPercent: day <= DateTime.now().weekday ? 0.95 : null,
            ),
        ],
      ),

      // Location 3: Overnight restrictions
      ParkingLocation(
        lat: -37.8061,
        lng: 144.9744,
        description: "Chapel Street between Toorak Road and Commercial Road",
        restrictions: [
          for (int day = 1; day <= 7; day++) ...[
            // Day restriction
            ParkingRestriction(
              id: "mock_loc3_${day}_day",
              dayOfWeek: day,
              startTime: "09:00:00",
              endTime: "17:00:00",
              maximumStayMinutes: 120,
              occupancyPercent: day <= DateTime.now().weekday ? 0.68 : null,
            ),
            // Night restriction
            ParkingRestriction(
              id: "mock_loc3_${day}_night",
              dayOfWeek: day,
              startTime: "22:00:00",
              endTime: "06:00:00", // Next day
              maximumStayMinutes: 480, // 8 hours overnight
              occupancyPercent: day <= DateTime.now().weekday ? 0.23 : null,
            ),
          ]
        ],
      ),
    ];
  }

  /// Simulate the enhanced API response format
  /// This is what your friend should implement in the backend
  static Map<String, dynamic> getMockApiResponse() {
    final location = getMockParkingLocation();
    return {
      'location': {
        'lat': location.lat,
        'lng': location.lng,
        'description': location.description,
      },
      'restrictions': location.restrictions.map((r) => {
        'id': r.id,
        'day_of_week': r.dayOfWeek,
        'start_time': r.startTime,
        'end_time': r.endTime,
        'maximum_stay_minutes': r.maximumStayMinutes,
        'occupancy_percent': r.occupancyPercent,
      }).toList(),
    };
  }

  /// Documentation for backend implementation
  static String getApiDocumentation() {
    return '''
# Enhanced Parking Restrictions API

## Current State
- API: /api/map/getsignforpin
- Filter: WHERE ps.day_of_week = ? (current day only)
- Returns: Single restriction per location

## Required Changes
- Remove day filter to return all 7 days
- Group by location (lat/lng)
- Return all restrictions for each location

## New Response Format
```json
[
  {
    "location": {
      "lat": -37.8481,
      "lng": 144.9831,
      "description": "Street description"
    },
    "restrictions": [
      {
        "id": "1288",
        "day_of_week": 1,
        "start_time": "07:30:00",
        "end_time": "18:30:00",
        "maximum_stay_minutes": 660,
        "occupancy_percent": 0.09090909090909091
      },
      // ... more restrictions for days 2-7
    ]
  }
]
```

## SQL Query Update
```sql
SELECT
    DISTINCT ST_Y(ps.location::geometry) AS lat,
    ST_X(ps.location::geometry) AS lng,
    nb.description,
    JSON_AGG(
        JSON_BUILD_OBJECT(
            'id', ps.id,
            'day_of_week', ps.day_of_week,
            'start_time', ps.start_time,
            'end_time', ps.end_time,
            'maximum_stay_minutes', ps.maximum_stay_minutes,
            'occupancy_percent', ps.occupancy_percent
        ) ORDER BY ps.day_of_week
    ) as restrictions
FROM public.parking_signs ps
LEFT JOIN LATERAL (/* nearest parking bay */) nb ON TRUE
GROUP BY ST_Y(ps.location::geometry), ST_X(ps.location::geometry), nb.description
ORDER BY lat, lng;
```
    ''';
  }
}