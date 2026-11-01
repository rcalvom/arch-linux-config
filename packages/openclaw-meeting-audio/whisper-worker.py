#!/usr/bin/python3
"""Transcribe bounded PCM chunks in memory; never persist raw meeting audio."""
import base64
import json
import sys
from pathlib import Path

import numpy as np
import torch
import whisper


def emit(value):
    print(json.dumps(value), flush=True)


def main():
    # Require the existing model; do not implicitly download software or models.
    checkpoint = Path.home() / '.cache/whisper/base.pt'
    if not checkpoint.is_file():
        raise RuntimeError('The local Whisper base model is missing')
    torch.set_num_threads(4)
    model = whisper.load_model(str(checkpoint), device='cpu')
    emit({'ready': True})
    for line in sys.stdin:
        if len(line) > 1500000:
            raise ValueError('Audio chunk exceeds the input limit')
        request = json.loads(line)
        data = base64.b64decode(request['pcm'], validate=True)
        if len(data) % 2 or len(data) > 16000 * 2 * 30:
            raise ValueError('Invalid PCM chunk size')
        audio = np.frombuffer(data, dtype='<i2').astype(np.float32) / 32768.0
        if audio.size < 1600 or float(np.sqrt(np.mean(audio ** 2))) < 0.001:
            emit({'done': True, 'text': ''})
            continue
        result = model.transcribe(audio, fp16=False, verbose=None,
                                  condition_on_previous_text=False)
        text = ' '.join(s['text'].strip() for s in result['segments']
                        if s.get('no_speech_prob', 0) < 0.6).strip()
        emit({'done': True, 'text': text})


if __name__ == '__main__':
    try:
        main()
    except Exception:
        # Dependencies can include input text in errors; do not log those errors.
        emit({'error': 'Local Whisper worker failed'})
        sys.exit(1)
