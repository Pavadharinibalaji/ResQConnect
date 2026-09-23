# API Design & Communication Standards

This document establishes the communication rules, response formats, and transaction tracing protocols for the **ResQConnect** API service.

---

## ⚡ Unified Response Formats

All API responses must wrap data inside a standard structure to ensure consistent consumption across clients (iOS, Android, Web).

### 1. Success Response (HTTP 200/201)
Returned by all successful query operations.
```json
{
  "success": true,
  "message": "Operation description summary",
  "data": {
    "key": "value"
  },
  "timestamp": "2026-07-21T22:45:00.000000",
  "request_id": "3a0d5cbe-a1c1-4c1d-8b01-5d6b8e3a2c6d"
}
```

### 2. Error Response (HTTP 4xx/5xx)
Returned when a request validation fails or an internal exception occurs.
```json
{
  "success": false,
  "message": "Human-readable explanation of what failed.",
  "error_code": "VALIDATION_ERROR",
  "timestamp": "2026-07-21T22:45:00.000000",
  "request_id": "3a0d5cbe-a1c1-4c1d-8b01-5d6b8e3a2c6d"
}
```

### 3. Error bodies as currently returned by the backend
- **Validation failures (HTTP 422)**: request bodies, path and query parameters that fail Pydantic validation (wrong JSON type, missing required field, value out of range, custom validator such as `username`, malformed JSON) always return a JSON body. `detail` lists each error with `loc`, `msg` and `type` (plus `input`/`ctx` where Pydantic provides them); values that cannot be represented in JSON, such as validator exceptions or `NaN`/`Infinity`, are returned as strings.
  ```json
  {
    "success": false,
    "detail": [
      {"type": "value_error", "loc": ["body", "username"],
       "msg": "Value error, Username must be 3-30 characters long and contain only letters, numbers, and underscores.",
       "input": "bad name!", "ctx": {"error": "Username must be 3-30 characters long and contain only letters, numbers, and underscores."}}
    ]
  }
  ```
- **Handled errors (4xx)**: `{"detail": "<message>"}` (or `{"detail": "<message>", "success": false}`). For example, `PATCH /api/v1/incidents/{id}/status` with an `assigned_responder_id` that is not an existing user returns `404 {"detail": "Assigned responder not found."}` instead of a database error.
- **Unhandled errors (HTTP 500)**: always `{"detail": "Internal server error", "success": false}`. Exception messages, SQL and stack traces are logged server-side only, never returned to clients.

---

## 🆔 Request ID & Transaction Tracing

To facilitate distributed tracing and easy production troubleshooting, we implement **Request ID tracking**:

1. **Generation**: If the client doesn't send an `X-Request-ID` header, the backend `RequestIDMiddleware` generates a unique UUID.
2. **Context**: The Request ID is stored in a thread-safe Python `contextvars` instance. Every system log generated during that transaction contains the request ID.
3. **Response Header**: The backend returns `X-Request-ID` in the response headers.
4. **Client Interceptor**: The Flutter `DioClient` automatically generates a Request ID for each outgoing call, injects it, and logs response headers.

---

## 🌐 HTTP Status Codes Policy

| Code | Usage | Target Schema |
|---|---|---|
| **200 OK** | Successful read/update transactions | `StandardResponse` |
| **201 Created** | Successful entity creations | `StandardResponse` |
| **400 Bad Request** | Missing payload fields or invalid query logic | `ErrorResponse` |
| **401 Unauthorized** | Expired or missing Bearer token authentication | `ErrorResponse` |
| **422 Unprocessable** | Input validation constraints broken (Pydantic validation) | `ErrorResponse` |
| **500 Internal Error** | Database link down or unhandled runtime server exception | `ErrorResponse` |
