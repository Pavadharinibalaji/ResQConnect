# Coding Standards & Styleguide

This document defines the coding rules and conventions applied throughout the **ResQConnect** codebase.

---

## 🏛 SOLID Principles Enforcement

1. **Single Responsibility Principle (SRP)**:
   - **Flutter**: Usecases execute exactly one business operation. UI Widgets only present data and delegate events to Riverpod providers.
   - **FastAPI**: Endpoint routers only handle routing and input validation (Pydantic), delegating logic to services, and database queries to repositories.
2. **Open/Closed Principle (OCP)**:
   - Extend functionalities by subclassing or passing adapters rather than modifying existing classes.
3. **Liskov Substitution Principle (LSP)**:
   - Subtypes must be substitutable for their base types (e.g. mock repositories must implement the same interface as real data repositories).
4. **Interface Segregation Principle (ISP)**:
   - Avoid fat interfaces. Segregate repository definitions into smaller, highly cohesive abstractions.
5. **Dependency Inversion Principle (DIP)**:
   - High-level modules (usecases/services) must not depend on low-level modules (datasources/db drivers). Both must depend on abstractions.

---

## 📱 Flutter / Dart Coding Standards

- **State Management**: Use **Riverpod**. State is kept in immutable classes. Modify state by emitting new versions via `StateNotifier`.
- **Immutability**: Prefer `const` constructors where possible to reduce build overhead.
- **Routing**: Explicitly reference router paths in `routes/app_router.dart`. Do not hardcode strings for paths inside UI layers.
- **Pure Dart Models (No Codegen Fallback)**:
   - When building models in resource-constrained compilation environments (where build_runner thread allocation fails), write standard Dart models with manual `fromJson`, `toJson`, and `copyWith` structures. Do not mix code generator annotations with pure implementations.
- **Naming Conventions**:
   - Files: `snake_case.dart` (e.g., `splash_page.dart`)
   - Classes: `PascalCase` (e.g., `ResQButton`)
   - Methods/Variables: `camelCase` (e.g., `verifyPhoneNumber`)
- **Formatting**: Format all files using the built-in Dart formatter (`dart format`).

---

## 🐍 FastAPI / Python Coding Standards

- **Type Hints**: All functions must declare input parameter types and return type annotations.
- **Asynchronous Execution**: Always declare database-interacting endpoints with `async def` and use `await` on database session executions.
- **Validation**: Use Pydantic v2 schemas for checking request payloads and serializing JSON outputs.
- **Request ID Logging**:
   - Every log message printed by uvicorn or resqconnect logger must include the current `request_id` from contextvars.
   - Access logs must capture HTTP method, route path, status code, and latency in milliseconds.
- **Global Error Schemas**:
   - Never let database errors or unhandled system exceptions escape to the client in raw formats.
   - Always catch exceptions globally and map them to `ErrorResponse` formats with standard codes (`VALIDATION_ERROR`, `DATABASE_ERROR`, `INTERNAL_SERVER_ERROR`).
- **Styling**: Adhere strictly to **PEP 8** style guidelines. Format code using formatting tools (like Black or Ruff).
