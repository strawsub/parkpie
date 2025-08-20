# ParkPie

ParkPie is a community-driven parking sign recognition and inspector alert application for Melbourne.  
Users can take photos of parking signs, which are processed via computer vision, and can also report parking inspectors in real time.

---

## Tech Stack
- **Frontend**: Flutter
- **Backend**: Java 24, Spring Boot 3.5.4, Spring Data JPA, Hibernate
- **Database**: PostgreSQL 17
- **Deployment**: AWS

---

## Project Structure

```
parkpie/ (root)
├── apps/
│ ├── backend/ # Java Spring Boot API
│ └── frontend/ # Flutter app
├── docs/
│ ├── deployment/ # Deployment Guides
│ └── architecture/ # System Architecture
└── README.md # This file
```

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/EnderFr0zen/parkpie.git
cd parkpie
```

### 2. Backend Setup

```bash
cd apps/backend
./gradlew build
./gradlew bootRun
```

### 3. Frontend Setup

```bash
cd apps/frontend
flutter pub get
flutter run
```

---

## Commit Message Convention

This project follows the [Conventional Commits](https://www.conventionalcommits.org/) specification.

**Format**
```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

**Common types**
- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation changes only
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code changes that neither fix a bug nor add a feature
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance changes (build tools, dependencies, etc.)
- **build**: Changes to the build system or external dependencies
- **ci**: Changes to CI configuration or scripts
- **revert**: Revert a previous commit

**Example**
```
feat(auth): add user login API
```

---

## License
MIT License
