"""Silero TTS локально из snakers4/silero-models — теперь v5_5_ru, голос kseniya."""
import io
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import soundfile as sf

# v5_5_ru: валидные спикеры по репозиторию snakers4/silero-models
AVAILABLE_SPEAKERS = {"aidar", "baya", "eugene", "random", "xenia", "kseniya"}

class TTSRequest(BaseModel):
    text: str
    speaker: str = "kseniya"
    sample_rate: int = 24000

app = FastAPI(title="Silero TTS v5_5_ru local")
model = None

@app.on_event("startup")
def load_model():
    global model
    model, _ = torch.hub.load(
        repo_or_dir="snakers4/silero-models",
        model="silero_tts",
        language="ru",
        speaker="v5_5_ru",           # <-- версия 5_5
        trust_repo=True,
    )
    model.to("cpu")

@app.get("/health")
def health():
    return {"status": "ok", "speakers": sorted(AVAILABLE_SPEAKERS)}

@app.post("/tts")
def tts(req: TTSRequest):
    if req.speaker not in AVAILABLE_SPEAKERS:
        raise HTTPException(400, f"нет такого: {req.speaker!r}; есть {sorted(AVAILABLE_SPEAKERS)}")
    audio = model.apply_tts(
        text=req.text,
        speaker=req.speaker,
        sample_rate=req.sample_rate,
    )
    buf = io.BytesIO()
    sf.write(buf, audio.cpu().numpy(), req.sample_rate, format="WAV", subtype="PCM_16")
    return __import__("fastapi").responses.Response(
        content=buf.getvalue(), media_type="audio/wav"
    )
