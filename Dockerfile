# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (Production-ready Multi-stage Dockerfile)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: builder
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy built dependencies from builder stage
COPY --from=builder /install /usr/local

# Tạo user thường không chạy bằng root
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn ứng dụng
COPY . .
RUN chown -R appuser:appuser /app

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, os; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
