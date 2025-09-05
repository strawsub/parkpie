# Continuous Integration (CI)

This repository contains two applications with baseline GitHub Actions CI:

- Backend (Spring Boot, Gradle) at `apps/backend`
- Frontend (Flutter) at `apps/frontend`

## What’s Included

- Path‑scoped workflows so each pipeline runs only when its app changes.
- Build and test steps aligned to each stack.
- Caching for Gradle and Flutter to speed up subsequent runs.
- Artifacts: backend JAR build output is uploaded; Flutter coverage is uploaded if present.

## Workflows

- `.github/workflows/backend-ci.yml`
  - Java 21 (Temurin) with Gradle wrapper caching.
  - Runs `./gradlew test --no-daemon` and `./gradlew build --no-daemon`.
  - Uploads `apps/backend/build/libs/*.jar` as an artifact.

- `.github/workflows/frontend-ci.yml`
  - Installs Flutter (stable channel) and Java 21 for Android toolchain.
  - Runs `flutter pub get`, `flutter analyze`, and `flutter test`.
  - Uploads `apps/frontend/coverage/lcov.info` if generated.

## Triggers

- `push` and `pull_request` events filtered to app paths: `apps/backend/**` and `apps/frontend/**`.
- Update the corresponding workflow files to trigger CI for pipeline changes.

## Local Parity

- Backend: `cd apps/backend && ./gradlew test build`
- Frontend: `cd apps/frontend && flutter pub get && flutter analyze && flutter test`
