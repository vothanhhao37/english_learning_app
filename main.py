from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import whisper
import os
import shutil
import torch

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = whisper.load_model("medium").to("cuda")  # 🔥 Load model vào GPU

@app.post("/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    temp_path = f"temp_{audio.filename}"
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)

    result = model.transcribe(
        temp_path,
        language="en",
        task="transcribe",
        temperature=0,
        beam_size=1,
        best_of=1,
        fp16=True,  # 🔥 Dùng fp16 tăng tốc
    )

    os.remove(temp_path)
    return JSONResponse(content={"text": result["text"]})

@app.get("/")
async def root():
    return {"message": "Whisper API is running"}
