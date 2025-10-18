# Restriction Duration API

The restriction duration API answers the question: "If I park here now, how long before I have to move?"
It inspects nearby parking-sign schedules and reports either the remaining time in the current restriction
window or the gap until the next restriction starts.

## Endpoint

```
GET /api/map/restrictionduration
```

### Query Parameters

| Name        | Type    | Required | Description                                                                                                                  |
|-------------|---------|----------|------------------------------------------------------------------------------------------------------------------------------|
| `lat`       | double  | yes      | Latitude of the parked vehicle in WGS84 (EPSG:4326).                                                                         |
| `lng`       | double  | yes      | Longitude of the parked vehicle in WGS84 (EPSG:4326).                                                                        |
| `startTime` | string  | yes      | Parking start time. Accepts ISO-8601 strings with an offset (`2025-10-10T15:00:00+10:00`) or a local timestamp interpreted   |
|             |         |          | as Australia/Melbourne time.                                                                                                 |
| `zone`      | integer | no       | Preferred manual zone number (negative) returned from the sign scanner. When provided, the service attempts that zone first |
|             |         |          | before falling back to the closest detected signage.                                                                         |

## Response

The endpoint returns one of the following:

* A JSON object describing the duration.
* `null` if no parking signs are found within 100 m of the provided location.
* `400 Bad Request` if the input is malformed.

### Successful Response Body

```jsonc
{
  "durationMinutes": 30,
  "scenario": "ACTIVE_RESTRICTION",
  "maxStayMinutes": 30,
  "zoneNumber": 1234,
  "distanceMeters": 8.4,
  "restrictionWindowEnd": "2025-10-10T15:30:00+11:00",
  "nextRestrictionStart": null,
  "matchedByZoneId": true
}
```

Fields:

| Field                  | Type     | Description                                                                                                     |
|------------------------|----------|-----------------------------------------------------------------------------------------------------------------|
| `durationMinutes`      | integer  | Minutes until the vehicle must move.                                                                            |
| `scenario`             | string   | `ACTIVE_RESTRICTION` (currently restricted) or `UNTIL_NEXT_RESTRICTION` (between windows).                       |
| `maxStayMinutes`       | integer? | Maximum consecutive stay allowed in the relevant restriction. May be `null` if unrestricted.                    |
| `zoneNumber`           | integer  | The zone number whose restrictions were evaluated.                                                              |
| `distanceMeters`       | double   | Distance from the queried location to the sign that supplied the restriction windows.                           |
| `restrictionWindowEnd` | string?  | ISO-8601 timestamp for when the current restriction ends. Present for `ACTIVE_RESTRICTION`.                     |
| `nextRestrictionStart` | string?  | ISO-8601 timestamp for when the next restriction begins. Present for `UNTIL_NEXT_RESTRICTION`.                  |
| `matchedByZoneId`      | boolean  | `true` when the provided `zone` parameter matched signage; `false` when the value comes from a fallback search. |

### Examples

1. **Active restriction with stay limit**  
   `lat=-37.8150&lng=144.9650&startTime=2025-10-10T15:00:00+11:00` (Queen St at 3 pm) -> returns `durationMinutes:30`.

2. **Between restrictions**  
   `lat=-37.8150&lng=144.9650&startTime=2025-10-10T21:00:00+11:00` (Queen St at 9 pm) -> returns ~11 hours until next restriction.

3. **No signage nearby**  
   `lat=-37.8198&lng=144.9655&startTime=2025-10-10T15:00:00+11:00` (Union St, no sign within 100 m) -> returns `null`. If a `zone` is provided and neither that zone nor nearby signage is found, the service responds with `404 Not Found`.

### Error Response

If `startTime` cannot be parsed, the API responds with:

```
HTTP 400 Bad Request
{
  "status": 400,
  "error": "Bad Request",
  "message": "Invalid startTime format. Use ISO-8601, e.g. 2025-10-10T15:00:00+10:00"
}
```

## Implementation Notes

* The backend searches parking signs within a 100 m radius using PostGIS distances.  
* All times are converted to Australia/Melbourne to respect local restrictions.  
* If multiple signs exist, the nearest zone is chosen (ties broken by zone number) unless a preferred `zone` is supplied.  
* Unit tests cover active restriction, next restriction, preferred-zone handling, and no signage scenarios.  
* The Flutter timer feature calls this endpoint after a sign scan. When the lookup fails, the client prompts the user to reselect or rescan a sign.
