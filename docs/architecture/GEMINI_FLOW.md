# Gemini Sign-Scanning Flow

This document captures the structure and behaviour of the Gemini-powered parking-sign ingestion feature introduced in the ParkPie frontend (Flutter) and the paths where supporting code lives.

## Inputs Provided to Gemini

### 1. OCR Phase (`CameraBloc._onPhotoUploaded`)
- **Source**: Captured JPEG photo from the camera (`PhotoUploaded.imagePath`).
- **Prompt**:
  ````text
  Extract all the readable text from this parking sign image.
  ````
- **Payload**: `Content.multi` containing a `TextPart` with the above instruction and a `DataPart` with the JPEG bytes.
- **Model**: `gemini-2.5-flash-lite` (see `apps/frontend/lib/features/camera/camera_bloc.dart`).
- **Output expectations**: Free-form text – the raw OCR transcript used later for summarisation and structured extraction.

### 2. Structured Restriction Extraction (`SignIngestService.extractSignJson`)
- **Prompt** (system instruction, `apps/frontend/lib/services/sign_ingest_service.dart:11-28`):
  ````text
  You are extracting Australian parking sign restrictions exactly as written.
  Respond with a single JSON object only. No markdown, prose, or extra keys.
  JSON schema:
  {
    "location": { "lat": number, "lng": number },
    "restrictions": [
      { "day_of_week": int (1..7), "start_time": "HH:mm", "end_time": "HH:mm", "maximum_stay_minutes": int|null }
    ]
  }
  Guidelines:
  - Include the restrictions exactly as the sign states; omit days that are not listed.
  - Multiple entries for the same day are allowed and should be ordered top-to-bottom from the sign.
  - Use 24-hour "HH:mm" format; use "00:00" for midnight.
  - If the stay duration is unlimited or not stated, set "maximum_stay_minutes" to null.
  Return strict JSON only.
  ````
- **Invocation**: `gemini-1.5-pro-latest` with a single text prompt that embeds the raw OCR text plus the current lat/lng (from device GPS).
- **Expected JSON shape**:
  ```json
  {
    "location": { "lat": -37.814, "lng": 144.96332 },
    "restrictions": [
      {
        "day_of_week": 1,
        "start_time": "08:00",
        "end_time": "18:00",
        "maximum_stay_minutes": 120
      },
      {
        "day_of_week": 1,
        "start_time": "18:00",
        "end_time": "23:59",
        "maximum_stay_minutes": null
      }
      // ... 1–42 entries total, in sign order
    ]
  }
  ```
- **Cardinality constraints**: The client accepts between 1 and 42 restriction rows (`UserSignIngestDto.Request.restrictions`); duplicates per day are permitted so long as (day, start_time, end_time) is unique.

### 3. Explanation Generation (`SignIngestService.generateExplanation`)
- **Prompt** (constructed at runtime, `sign_ingest_service.dart:118-136`):
  ````text
  Sign location: (<lat>, <lng>)
  Original extracted text:
  <raw OCR text>

  Structured restrictions (JSON array):
  <JSON array from Gemini>

  Explain these rules in friendly Australian English (<=120 words). Mention day ranges and stay limits clearly.
  ````
- **Model**: `gemini-1.5-flash-latest` (text-only).
- **Expected output**: Short paragraph summarising the parking rules; trimmed result may be empty if Gemini fails.

## Output Destinations

### A. Backend payload (`/signs/ingest`)
- **Collector**: `SignIngestService.sendToBackend` (Flutter) → `ParkingSignService.ingestUserSign` (Spring Boot).
- **JSON posted**:
  ```json
  {
    "location": { "lat": -37.814, "lng": 144.96332 },
    "restrictions": [
      { "day_of_week": 1, "start_time": "08:00", "end_time": "18:00", "maximum_stay_minutes": 120 },
      { "day_of_week": 1, "start_time": "18:00", "end_time": "23:59", "maximum_stay_minutes": null }
      // ...
    ],
    "zone_number": -12345 // optional; provided when client already has a cached manual zone
  }
  ```
- **Behaviour**:
  - If `zone_number` is present (must be negative), the backend clears existing windows for that zone before upserting (`ParkingSignService.ingestUserSign`).
  - Otherwise, the backend allocates a new negative zone id from `manual_zone_number_seq` (ensured by `DbPolishRunner`).
- **Response** (`UserSignIngestDto.Response` → `SignIngestResult`):
  ```json
  {
    "zone_number": -12345,
    "restrictions_saved": 7,
    "replaced_previous": 2
  }
  ```
  The Flutter client caches `zone_number` keyed by location+window hash (`SignZoneStorage`) and displays the counts in the summary card.

### B. User-facing display (Camera UI)
- **Explanation**: Gemini commentary shown in the “Gemini explanation” card; fallback text warns when no summary is available.
- **Structured list**: Each restriction row is rendered with day label, localised time range (`TimeOfDay.format`), and stay duration text (handles null/0/integer minutes).
- **Raw OCR transcript**: Available under an expansion panel for transparency/debugging.
- **Snackbars**: Inform users when a zone is new vs. updated (uses `restrictions_saved`/`replaced_previous`).

## Gemini Output Constraints
- **Restriction count**: 1–42 entries (client validation); duplicates with identical day/start/end are collapsed before persistence.
- **Time format**: Strict `HH:mm` 24-hour strings; client rejects invalid patterns.
- **Day values**: Integers `1..7` (Mon..Sun); outside this range triggers validation errors.
- **Maximum stay**: Integer minutes ≥ 0 or `null` (unlimited/unstated).
- **Location**: Latitude ∈ [-90, 90], longitude ∈ [-180, 180]; enforced client-side before POST.

## Key Source Files
- `apps/frontend/lib/features/camera/camera_bloc.dart`
- `apps/frontend/lib/features/camera/camera_state.dart`
- `apps/frontend/lib/features/camera/camera_screen.dart`
- `apps/frontend/lib/services/sign_ingest_service.dart`
- `apps/frontend/lib/services/sign_zone_storage.dart`
- `apps/frontend/lib/features/camera/sign_restriction.dart`
- `apps/backend/src/main/java/com/parkpie/backend/parking/service/ParkingSignService.java`
- `apps/backend/src/main/java/com/parkpie/backend/parking/dto/UserSignIngestDto.java`
- `apps/backend/src/main/java/com/parkpie/backend/core/config/DbPolishRunner.java`

## Sequence Summary
1. User captures photo → Gemini OCR → raw text.
2. Client prompts Gemini with OCR text + location → receives JSON restrictions.
3. Client validates & merges cached zone number, POSTs to `/signs/ingest`.
4. Backend upserts restrictions into `parking_signs`, returns zone metadata.
5. Client caches `zone_number`, renders summary card & Gemini explanation, stores negative zone id for future rescans.
