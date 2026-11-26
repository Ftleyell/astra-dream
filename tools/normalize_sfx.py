"""Normalizador y decodificador CLI de SFX usando ffmpeg.

Convierte archivos de audio externos (.wav, .ogg, .mp3, .flac) a WAV PCM 16-bit
listos para Godot, con recorte opcional de silencio inicial/final, fade-out
anti-click y normalizacion exacta de pico.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import wave
from pathlib import Path

DEFAULT_FFMPEG_FALLBACKS: tuple[str, ...] = (
    "ffmpeg",
    r"C:\Users\Frani\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe",
)

MAX_VOLUME_RE = re.compile(r"max_volume:\s*([-\d.]+|-inf)\s*dB")


def resolve_ffmpeg(explicit_path: str | None = None) -> str:
    """Resuelve la ruta ejecutable de ffmpeg."""
    if explicit_path and Path(explicit_path).is_file():
        return explicit_path
    found = shutil.which("ffmpeg")
    if found:
        return found
    for candidate in DEFAULT_FFMPEG_FALLBACKS:
        if Path(candidate).is_file():
            return candidate
    raise FileNotFoundError("No se encontro ffmpeg en PATH ni en rutas conocidas.")


def run_ffmpeg(ffmpeg_bin: str, args: list[str]) -> subprocess.CompletedProcess[str]:
    """Ejecuta ffmpeg capturando salida sin shell intermedia."""
    cmd = [ffmpeg_bin, "-hide_banner", "-nostdin", "-y", *args]
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def measure_wav_info(wav_path: Path) -> tuple[float, int, int]:
    """Devuelve (duration_ms, sample_rate, channels) de un archivo WAV PCM."""
    with wave.open(str(wav_path), "rb") as wf:
        frames = wf.getnframes()
        rate = wf.getframerate()
        channels = wf.getnchannels()
        duration_ms = (frames / float(rate)) * 1000.0 if rate > 0 else 0.0
        return duration_ms, rate, channels


def detect_peak_db(ffmpeg_bin: str, input_path: Path, filter_chain: str) -> float:
    """Ejecuta volumedetect sobre la cadena de filtros previa y retorna max_volume en dB."""
    vf = f"{filter_chain},volumedetect" if filter_chain else "volumedetect"
    proc = run_ffmpeg(ffmpeg_bin, ["-i", str(input_path), "-af", vf, "-f", "null", os.devnull])
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "ffmpeg volumedetect fallo.")
    match = MAX_VOLUME_RE.search(proc.stderr)
    if not match:
        return 0.0
    raw = match.group(1)
    if raw == "-inf":
        return -90.0
    return float(raw)


def build_trim_filter(trim_silence: bool) -> str:
    """Construye la cadena de recorte de silencio inicial y final."""
    if not trim_silence:
        return ""
    return (
        "silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB,"
        "areverse,"
        "silenceremove=start_periods=1:start_duration=0:start_threshold=-50dB,"
        "areverse"
    )


def export_normalized(
    ffmpeg_bin: str,
    input_path: Path,
    output_path: Path,
    gain_db: float,
    target_peak_db: float,
    trim_silence: bool,
    fade_out_ms: float,
    mono: bool,
    sample_rate: int,
) -> dict[str, object]:
    """Normaliza, recorta y exporta un SFX a WAV PCM 16-bit."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    trim_chain = build_trim_filter(trim_silence)
    try_trim = trim_silence

    while True:
        pre_chain = trim_chain if try_trim else ""
        peak_before = detect_peak_db(ffmpeg_bin, input_path, pre_chain)
        applied_gain = (target_peak_db - peak_before) + gain_db
        # Limitar ganancia extrema en clips silenciosos.
        applied_gain = max(-48.0, min(36.0, applied_gain))

        filters: list[str] = []
        if pre_chain:
            filters.append(pre_chain)
        if abs(applied_gain) > 0.01:
            filters.append(f"volume={applied_gain:.3f}dB")
        filters.append("alimiter=limit=0.98:attack=1:release=25:level=disabled")

        temp_out = output_path.with_suffix(".tmp_norm.wav")
        cmd_args = [
            "-i",
            str(input_path),
            "-af",
            ",".join(filters),
            "-ar",
            str(sample_rate),
            "-c:a",
            "pcm_s16le",
        ]
        if mono:
            cmd_args.extend(["-ac", "1"])
        cmd_args.append(str(temp_out))

        proc = run_ffmpeg(ffmpeg_bin, cmd_args)
        if proc.returncode != 0 or not temp_out.is_file():
            if try_trim:
                try_trim = False
                continue
            raise RuntimeError(proc.stderr.strip() or "ffmpeg fallo al generar WAV.")

        duration_ms, rate, channels = measure_wav_info(temp_out)
        if duration_ms < 8.0 and try_trim:
            temp_out.unlink(missing_ok=True)
            try_trim = False
            continue

        # Aplicar fade-out anti-click al final usando la duracion medida real.
        if fade_out_ms > 0.0 and duration_ms > fade_out_ms + 2.0:
            fade_sec = fade_out_ms / 1000.0
            start_sec = max(0.0, (duration_ms / 1000.0) - fade_sec)
            fade_filter = f"afade=t=out:st={start_sec:.6f}:d={fade_sec:.6f}"
            fade_args = [
                "-i",
                str(temp_out),
                "-af",
                fade_filter,
                "-ar",
                str(sample_rate),
                "-c:a",
                "pcm_s16le",
                str(output_path),
            ]
            fade_proc = run_ffmpeg(ffmpeg_bin, fade_args)
            temp_out.unlink(missing_ok=True)
            if fade_proc.returncode != 0 or not output_path.is_file():
                raise RuntimeError(fade_proc.stderr.strip() or "ffmpeg fade-out fallo.")
            duration_ms, rate, channels = measure_wav_info(output_path)
        else:
            temp_out.replace(output_path)

        return {
            "ok": True,
            "output": str(output_path),
            "duration_ms": round(duration_ms, 2),
            "sample_rate": rate,
            "channels": channels,
            "peak_db_before": round(peak_before, 2),
            "applied_gain_db": round(applied_gain, 2),
            "trimmed": try_trim,
        }


def decode_preview(ffmpeg_bin: str, input_path: Path, output_path: Path, sample_rate: int) -> dict[str, object]:
    """Decodifica rapido cualquier audio a WAV PCM 16-bit para previsualizacion en Godot."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    proc = run_ffmpeg(
        ffmpeg_bin,
        [
            "-i",
            str(input_path),
            "-ar",
            str(sample_rate),
            "-c:a",
            "pcm_s16le",
            str(output_path),
        ],
    )
    if proc.returncode != 0 or not output_path.is_file():
        raise RuntimeError(proc.stderr.strip() or "ffmpeg decode-preview fallo.")
    duration_ms, rate, channels = measure_wav_info(output_path)
    return {
        "ok": True,
        "output": str(output_path),
        "duration_ms": round(duration_ms, 2),
        "sample_rate": rate,
        "channels": channels,
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Normalizador de SFX para Stela Galactica.")
    parser.add_argument("--input", required=True, help="Ruta de entrada (.wav/.ogg/.mp3/.flac)")
    parser.add_argument("--output", required=True, help="Ruta WAV de salida")
    parser.add_argument("--gain-db", type=float, default=0.0, help="Offset adicional de ganancia en dB")
    parser.add_argument("--target-peak-db", type=float, default=-1.0, help="Pico objetivo en dB")
    parser.add_argument(
        "--trim-silence",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Recortar silencio inicial y final",
    )
    parser.add_argument("--fade-out-ms", type=float, default=5.0, help="Fade-out anti-click en ms")
    mono_group = parser.add_mutually_exclusive_group()
    mono_group.add_argument("--mono", dest="mono", action="store_true", help="Forzar salida mono")
    mono_group.add_argument("--stereo", dest="mono", action="store_false", help="Preservar canales")
    parser.set_defaults(mono=True)
    parser.add_argument("--sample-rate", type=int, default=44100, help="Frecuencia de muestreo WAV")
    parser.add_argument("--ffmpeg", default=None, help="Ruta opcional a ffmpeg.exe")
    parser.add_argument(
        "--decode-preview",
        action="store_true",
        help="Solo decodificar a WAV 16-bit sin recortar ni normalizar",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    input_path = Path(args.input)
    output_path = Path(args.output)
    try:
        if not input_path.is_file():
            raise FileNotFoundError(f"Archivo no encontrado: {input_path}")
        ffmpeg_bin = resolve_ffmpeg(args.ffmpeg)
        if args.decode_preview:
            result = decode_preview(ffmpeg_bin, input_path, output_path, args.sample_rate)
        else:
            result = export_normalized(
                ffmpeg_bin=ffmpeg_bin,
                input_path=input_path,
                output_path=output_path,
                gain_db=args.gain_db,
                target_peak_db=args.target_peak_db,
                trim_silence=args.trim_silence,
                fade_out_ms=args.fade_out_ms,
                mono=args.mono,
                sample_rate=args.sample_rate,
            )
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
