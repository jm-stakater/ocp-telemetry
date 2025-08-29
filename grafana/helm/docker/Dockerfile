# Stage 1: Builder stage with build dependencies
FROM python:3.13-alpine AS builder

# Install OS packages needed to build python-ldap
#RUN apk add --no-cache openldap-dev gcc musl-dev

WORKDIR /install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix="/install" -r requirements.txt

# Stage 2: Final image, much smaller
FROM python:3.13-alpine

# Copy installed packages from the builder stage
COPY --from=builder /install /usr/local

# Copy the application code
WORKDIR /app
COPY sidecar.py .

# Run the application
CMD ["python", "sidecar.py"]