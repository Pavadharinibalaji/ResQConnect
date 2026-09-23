# Stage 1: Compile and install dependencies
FROM python:3.13-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Install packages into user path to copy easily
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Run container in lightweight context
FROM python:3.13-slim AS runner

WORKDIR /app

# Copy compiled python user-site libraries
COPY --from=builder /root/.local /root/.local
# Inject local path into PATH env variable
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Install runtime utilities (curl for health checks, libpq5 for PostgreSQL link)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy application sources
COPY . .

# Expose server port
EXPOSE 8000

# Run FastAPI engine (Task 9 Versioning support)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
