#!/usr/bin/env python3
"""Generate three polished UI sound effects for the TagShelf Flutter app.

Dependencies:
    numpy
    One MP3 encoder: lameenc (Python package), ffmpeg, lame, or macOS afconvert

The synthesis master is 44.1 kHz / 16-bit / mono and peak-normalized to
-1.0 dBFS before MP3 encoding. A fixed random seed makes the result exactly
repeatable at the PCM-master stage.
"""

from __future__ import annotations

import argparse
import importlib.util
import math
import shutil
import subprocess
import tempfile
import wave
import zipfile
from pathlib import Path

import numpy as np


SAMPLE_RATE = 44_100
TARGET_DBFS = -1.0
TARGET_PEAK = 10.0 ** (TARGET_DBFS / 20.0)
RNG = np.random.default_rng(0x7A65_5348)  # "TagShelf", fixed for repeatability


def time_axis(duration: float) -> np.ndarray:
    return np.arange(round(duration * SAMPLE_RATE), dtype=np.float64) / SAMPLE_RATE


def sine(freq: float, t: np.ndarray, phase: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * np.pi * freq * t + phase)


def smooth_attack(t: np.ndarray, seconds: float) -> np.ndarray:
    """Raised-cosine attack with zero slope at both ends."""
    x = np.clip(t / seconds, 0.0, 1.0)
    return 0.5 - 0.5 * np.cos(np.pi * x)


def tail_fade(signal: np.ndarray, seconds: float) -> np.ndarray:
    count = min(len(signal), max(2, round(seconds * SAMPLE_RATE)))
    fade = 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, count))
    result = signal.copy()
    result[-count:] *= fade
    return result


def peak_normalize(signal: np.ndarray, dbfs: float = TARGET_DBFS) -> np.ndarray:
    """Remove tiny DC bias and normalize the PCM master to an exact peak."""
    signal = np.asarray(signal, dtype=np.float64)
    signal = signal - np.mean(signal)
    peak = float(np.max(np.abs(signal)))
    if not math.isfinite(peak) or peak <= 0.0:
        raise ValueError("Cannot normalize a silent or invalid signal")
    target = 10.0 ** (dbfs / 20.0)
    return signal * (target / peak)


def synth_tap() -> np.ndarray:
    """50 ms wooden/bubble pop: quick attack, warm body, clean release."""
    duration = 0.050
    t = time_axis(duration)

    # A fast downward pitch gesture gives the sound a soft, tactile "pop".
    start_hz, end_hz, glide_tau = 790.0, 610.0, 0.010
    phase_cycles = (
        end_hz * t
        + (start_hz - end_hz) * glide_tau * (1.0 - np.exp(-t / glide_tau))
    )
    body = np.sin(2.0 * np.pi * phase_cycles)
    body += 0.28 * np.sin(2.0 * np.pi * 1.72 * phase_cycles + 0.35)
    body += 0.10 * np.sin(2.0 * np.pi * 2.43 * phase_cycles + 1.10)

    # Very quiet, low-passed transient adds a wooden "knock" without hiss.
    noise = RNG.standard_normal(len(t))
    kernel = np.hanning(13)
    kernel /= np.sum(kernel)
    woody_transient = np.convolve(noise, kernel, mode="same")

    body_env = smooth_attack(t, 0.0008) * np.exp(-t / 0.0165)
    noise_env = smooth_attack(t, 0.00035) * np.exp(-t / 0.0040)
    signal = body * body_env + 0.055 * woody_transient * noise_env
    return peak_normalize(tail_fade(signal, 0.008))


def bell_note(freq: float, duration: float, brightness: float = 1.0) -> np.ndarray:
    """Transparent bell/marimba hybrid with rapidly decaying upper partials."""
    t = time_axis(duration)
    attack = smooth_attack(t, 0.0028)
    fundamental = sine(freq, t) * np.exp(-t / 0.185)
    octave = 0.20 * brightness * sine(2.0 * freq, t, 0.15) * np.exp(-t / 0.085)
    chime = 0.075 * brightness * sine(2.996 * freq, t, 0.55) * np.exp(-t / 0.050)
    warmth = 0.10 * sine(0.501 * freq, t, 0.30) * np.exp(-t / 0.120)
    return attack * (fundamental + octave + chime + warmth)


def synth_success() -> np.ndarray:
    """440 ms E6-G#6-B6 ascent with an elegant, reassuring decay."""
    duration = 0.440
    signal = np.zeros(round(duration * SAMPLE_RATE), dtype=np.float64)
    notes = (
        (0.000, 1318.510, 0.80),  # E6
        (0.092, 1661.219, 0.92),  # G#6
        (0.184, 1975.533, 1.00),  # B6
    )
    for start, freq, brightness in notes:
        offset = round(start * SAMPLE_RATE)
        note = bell_note(freq, duration - start, brightness)
        signal[offset : offset + len(note)] += note

    # Keep the last note present but avoid a sharp jump in loudness.
    signal *= 0.93 + 0.07 * np.linspace(0.0, 1.0, len(signal))
    return peak_normalize(tail_fade(signal, 0.030))


def mellow_tone(freq: float, duration: float) -> np.ndarray:
    """Rounded warning tone, richer than a sine but far softer than a buzzer."""
    t = time_axis(duration)
    attack = smooth_attack(t, 0.006)
    decay = np.exp(-t / 0.100)
    tone = sine(freq, t)
    tone += 0.17 * sine(2.0 * freq, t, 0.40)
    tone += 0.045 * sine(3.0 * freq, t, 0.90)
    # Subtle modulation helps the cue read clearly on a small phone speaker.
    modulation = 1.0 + 0.018 * sine(7.0, t)
    return tone * attack * decay * modulation


def synth_error() -> np.ndarray:
    """250 ms Eb4-C4 descent: clear warning, soft attack, no harsh buzz."""
    duration = 0.250
    signal = np.zeros(round(duration * SAMPLE_RATE), dtype=np.float64)
    notes = (
        (0.000, 311.127, 1.00),  # Eb4
        (0.105, 261.626, 0.92),  # C4
    )
    for start, freq, gain in notes:
        offset = round(start * SAMPLE_RATE)
        note = mellow_tone(freq, duration - start) * gain
        signal[offset : offset + len(note)] += note
    return peak_normalize(tail_fade(signal, 0.018))


def write_pcm16_wav(path: Path, signal: np.ndarray) -> None:
    """Write a 44.1 kHz, 16-bit, mono PCM WAV master."""
    pcm = np.clip(np.rint(signal * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())


def encode_mp3(wav_path: Path, mp3_path: Path) -> str:
    """Encode with the first available high-quality MP3 encoder."""
    if mp3_path.exists():
        mp3_path.unlink()

    if importlib.util.find_spec("lameenc") is not None:
        import lameenc

        with wave.open(str(wav_path), "rb") as wav:
            pcm_bytes = wav.readframes(wav.getnframes())
        encoder = lameenc.Encoder()
        encoder.set_bit_rate(192)
        encoder.set_in_sample_rate(SAMPLE_RATE)
        encoder.set_channels(1)
        encoder.set_quality(2)  # 0 is highest/slower, 9 is lowest/faster
        mp3_path.write_bytes(encoder.encode(pcm_bytes) + encoder.flush())
        encoder_name = "lameenc/LAME (192 kbps, quality 2)"
        command = None
    elif shutil.which("ffmpeg"):
        command = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(wav_path), "-ar", str(SAMPLE_RATE), "-ac", "1",
            "-codec:a", "libmp3lame", "-b:a", "192k", str(mp3_path),
        ]
        encoder_name = "ffmpeg/libmp3lame (192 kbps)"
    elif shutil.which("lame"):
        command = [
            "lame", "--quiet", "-b", "192", "-m", "m", "--resample", "44.1",
            str(wav_path), str(mp3_path),
        ]
        encoder_name = "lame (192 kbps)"
    elif shutil.which("afconvert"):
        command = [
            "afconvert", str(wav_path), str(mp3_path),
            "-f", "MPG3", "-d", ".mp3", "-b", "192000",
        ]
        encoder_name = "macOS afconvert (192 kbps requested)"
    else:
        raise RuntimeError("No MP3 encoder found. Install ffmpeg or lame.")

    if command is not None:
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as error:
            detail = (error.stderr or error.stdout or str(error)).strip()
            raise RuntimeError(f"MP3 encoding failed: {detail}") from error
    if not mp3_path.is_file() or mp3_path.stat().st_size == 0:
        raise RuntimeError(f"MP3 encoder did not create {mp3_path}")
    return encoder_name


def pcm_stats(signal: np.ndarray) -> tuple[float, float]:
    peak = float(np.max(np.abs(signal)))
    peak_dbfs = 20.0 * math.log10(peak)
    rms = float(np.sqrt(np.mean(np.square(signal))))
    rms_dbfs = 20.0 * math.log10(max(rms, np.finfo(float).tiny))
    return peak_dbfs, rms_dbfs


def generate(output_dir: Path, make_zip: bool = True) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    sounds = {
        "tap.mp3": synth_tap(),
        "success.mp3": synth_success(),
        "error.mp3": synth_error(),
    }

    encoders: set[str] = set()
    with tempfile.TemporaryDirectory(prefix="tagshelf_ui_sounds_") as temp:
        temp_dir = Path(temp)
        for filename, signal in sounds.items():
            wav_path = temp_dir / filename.replace(".mp3", "_master.wav")
            mp3_path = output_dir / filename
            write_pcm16_wav(wav_path, signal)
            encoders.add(encode_mp3(wav_path, mp3_path))
            peak_dbfs, rms_dbfs = pcm_stats(signal)
            print(
                f"{filename:12s}  {len(signal) / SAMPLE_RATE * 1000:6.1f} ms  "
                f"peak {peak_dbfs:5.2f} dBFS  RMS {rms_dbfs:6.2f} dBFS"
            )

    readme = output_dir / "README.txt"
    if readme.exists() and make_zip:
        package = output_dir / "TagShelf_UI_Sounds.zip"
        if package.exists():
            package.unlink()
        with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name in (
                "tap.mp3", "success.mp3", "error.mp3", "README.txt",
                "requirements.txt", Path(__file__).name,
            ):
                source = output_dir / name
                if source.is_file():
                    archive.write(source, arcname=name)
        print(f"Created {package.name}")

    print("Encoder:", ", ".join(sorted(encoders)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path, default=Path(__file__).resolve().parent,
        help="Destination directory (default: directory containing this script)",
    )
    parser.add_argument("--no-zip", action="store_true", help="Do not create the ZIP package")
    args = parser.parse_args()
    generate(args.output_dir.resolve(), make_zip=not args.no_zip)


if __name__ == "__main__":
    main()
