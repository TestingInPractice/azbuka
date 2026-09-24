FROM python:3.11-slim
WORKDIR /app
# ТАК в snakers4/silero-models: torch+torchaudio ОДНОЙ строкой из cpu-индекса (ABI совпадает!)
RUN pip install --no-cache-dir \
    torch \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir \
    omegaconf soundfile \
    fastapi "uvicorn[standard]"
COPY server.py .
EXPOSE 8000
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
