# ResQConnect

> **"When people need help, People respond."**

ResQConnect is a production-quality, real-time emergency coordination platform that connects responders with local crisis feeds. By enabling immediate mobile alerting and high-performance server-side data routing, the platform facilitates community-driven and agency-backed disaster responses.

---

## 🚀 Phase 1 Foundation

This codebase contains the complete foundation architecture (Phase 1) for both the mobile and backend components, structured to ensure scalability, security, clean code, and testability.

### Project Structure Overview

- **`mobile/`**: Flutter client application built with Feature-First Clean Architecture, Riverpod, GoRouter, and FlexColorScheme.
- **`backend/`**: FastAPI python web server implementing SQLAlchemy 2.0 (async), Pydantic v2, Alembic migrations, and JWT security tokens.
- **`database/`**: PostgreSQL and PostGIS spatial mapping configuration schema.
- **`deployment/`**: Docker containerization configs for rapid development and staging setups.
- **`docs/`**: Technical project design standards and documentation.

---

## 📖 Reference Documentation

For detailed guides, please refer to the files in the `docs/` folder:

1. **[Architecture & Design Standards](docs/Architecture.md)**: Architectural decisions, clean code guidelines, and SOLID principles implementation.
2. **[Folder Structure Map](docs/FolderStructure.md)**: Visual map of the directories and modular codebase layout.
3. **[Installation & Local Setup](docs/Installation.md)**: Step-by-step instructions to compile Flutter, spin up local Docker databases, and launch FastAPI APIs.
4. **[Coding Standards & Styleguide](docs/CodingStandards.md)**: Clean architecture style rules, Riverpod patterns, and Python coding guidelines.

---

## 🛠 Tech Stack Summary

| Component | Technology | Description |
|---|---|---|
| **Mobile Client** | Flutter / Dart | Stable cross-platform client using MVVM pattern |
| **State Management** | Riverpod | Compile-time safe state injection container |
| **Routing** | Go Router | Declarative path routing including 404 screens |
| **Backend API** | FastAPI / Python | High-performance async web framework |
| **ORM Database** | SQLAlchemy 2.0 / AsyncPG | Asynchronous DB interaction wrapper |
| **Migrations** | Alembic | SQL version control schema tracking |
| **Spatial Database** | PostgreSQL / PostGIS | Geospatial coordinate indexing and queries |
| **Containerization** | Docker / Compose | Multi-container environment runtime |
| **Authentication** | Firebase Phone OTP | Mobile numbers verified via secure token exchange |
