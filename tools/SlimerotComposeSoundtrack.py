"""Render Slimerot's original, scored chiptune soundtrack to local Ogg files.

Development tool only; the game has no Python or network dependency. Install
SlimerotMusicRequirements.txt, then run this script. The adjacent JSON is the
human-editable composition: eight-bar themes, contrasting bridges and voicings.
No samples, third-party recordings or quoted game melodies are used.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
import json
import math
from pathlib import Path
import re
import zlib

import numpy as np
from scipy import signal
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
TAU = 2 * math.pi
IDS = ("bedroom", "backyard", "italian_village", "cursed_forest", "sahara",
       "brainrot_city", "backrooms", "moon", "brainrot_dimension", "battle", "final_battle")
PITCHES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(note: str) -> int:
    match = re.fullmatch(r"([A-G])([#b]?)(-?\d)", note)
    if not match:
        raise ValueError(f"Invalid Slimerot pitch: {note}")
    letter, accidental, octave = match.groups()
    return 12 * (int(octave) + 1) + PITCHES[letter] + (1 if accidental == "#" else -1 if accidental == "b" else 0)


def envelope(t, held, attack, release):
    # Smooth attack/release prevents clicks, including notes which wrap the loop.
    a = np.sin(np.minimum(t / attack, 1.0) * math.pi / 2) ** 2
    r = np.cos(np.minimum(np.maximum(t - held, 0) / release, 1) * math.pi / 2) ** 2
    return a * r


@lru_cache(maxsize=768)
def voice(kind: str, pitch: int, held_samples: int) -> np.ndarray:
    held = held_samples / RATE
    releases = {"pad": .34, "keys": .23, "bell": .38, "pluck": .14, "flute": .10, "reed": .12, "bass": .065}
    release = releases.get(kind, .07)
    t = np.arange(math.ceil((held + release) * RATE), dtype=np.float32) / RATE
    hz = 440 * 2 ** ((pitch - 69) / 12)
    phase = TAU * hz * t
    # Delay vibrato until the onset settles; the pitch remains clear and tuneful.
    vib = np.sin(TAU * 5.2 * t) * np.minimum(t / .18, 1) * .025
    p = phase + vib
    attack = .008
    if kind in ("chip", "saw", "reed"):
        wave = np.zeros_like(t)
        for harmonic in range(1, min(14, int(RATE * .44 / hz)) + 1):
            if kind == "saw":
                amp = (-1) ** (harmonic + 1) / harmonic ** 1.45
            elif kind == "reed":
                amp = (1.0 if harmonic % 2 else .26) / harmonic ** 1.7
            else:
                amp = math.sin(math.pi * harmonic * .36) / harmonic ** 1.5
            wave += amp * np.sin(harmonic * p)
        wave /= 1.65
        wave *= .76 + .24 * np.exp(-t * 9)
        attack = .022 if kind == "reed" else .008
    elif kind == "flute":
        wave = .78 * np.sin(p) + .12 * np.sin(2 * p) + .035 * np.sin(3 * p)
        wave *= 1 + .018 * np.sin(TAU * 7.1 * t)
        attack = .035
    elif kind == "keys":
        wave = .7 * np.sin(p + 1.25 * np.exp(-t * 7) * np.sin(2 * p))
        wave += .13 * np.sin(2.002 * phase) * np.exp(-t * 5)
        wave *= .20 + .80 * np.exp(-t * 2.8)
        attack = .005
    elif kind == "bell":
        wave = .65 * np.sin(phase) * np.exp(-t * 2.4)
        for ratio, amp, decay in ((2, .22, 4), (2.76, .075, 7), (4.12, .025, 12)):
            if hz * ratio < RATE * .44:
                wave += amp * np.sin(ratio * phase) * np.exp(-t * decay)
        attack = .004
    elif kind == "pluck":
        wave = (.76 * np.sin(phase) + .16 * np.sin(2 * phase) + .06 * np.sin(3 * phase)) * np.exp(-t * 8)
        attack = .004
    elif kind == "bass":
        wave = .77 * np.sin(phase) + .16 * np.sin(2 * phase) + .055 * np.sin(3 * phase)
        wave *= .65 + .35 * np.exp(-t * 10)
        attack = .012
    elif kind == "pad":
        wave = .46 * np.sin(phase) + .22 * np.sin(phase * 1.0018) + .18 * np.sin(phase * .9982) + .045 * np.sin(2 * phase)
        attack = .14
    else:
        raise ValueError(kind)
    return (wave * envelope(t, held, attack, release)).astype(np.float32)


@lru_cache(maxsize=32)
def drum(kind: str) -> np.ndarray:
    rng = np.random.default_rng(zlib.crc32(kind.encode()))
    duration = {"kick": .34, "snare": .24, "hat": .07, "open_hat": .21, "rim": .09, "tom": .24}[kind]
    t = np.arange(int(duration * RATE), dtype=np.float32) / RATE
    noise = rng.uniform(-1, 1, len(t)).astype(np.float32)
    if kind == "kick":
        phase = TAU * (48 * t + 90 * .025 * (1 - np.exp(-t / .025)))
        wave = np.sin(phase) * np.exp(-t * 17) + .08 * noise * np.exp(-t * 220)
    elif kind == "snare":
        filtered = signal.sosfilt(signal.butter(2, 1500, "highpass", fs=RATE, output="sos"), noise)
        wave = .72 * filtered * np.exp(-t * 24) + .25 * np.sin(TAU * 185 * t) * np.exp(-t * 31)
    elif kind in ("hat", "open_hat"):
        filtered = signal.sosfilt(signal.butter(2, 6500, "highpass", fs=RATE, output="sos"), noise)
        wave = .53 * filtered * np.exp(-t * (64 if kind == "hat" else 20))
    elif kind == "rim":
        wave = (.7 * np.sin(TAU * 720 * t) + .3 * np.sin(TAU * 1120 * t)) * np.exp(-t * 90)
    else:
        wave = np.sin(TAU * (115 * t + 35 * .06 * (1 - np.exp(-t / .06)))) * np.exp(-t * 20)
    return (wave * np.minimum(t / .002, 1)).astype(np.float32)


class Arrangement:
    def __init__(self, score):
        self.score = score
        self.beat = 60 / score["bpm"]
        self.meter = score.get("beats_per_bar", 4)
        self.length = round(32 * self.meter * self.beat * RATE)
        self.mix = np.zeros((self.length, 2), dtype=np.float32)
        self.send = np.zeros_like(self.mix)

    def add(self, waveform, beat, gain, pan=0., reverb=.16):
        offset = round(beat * self.beat * RATE) % self.length
        stereo = waveform[:, None] * np.array([math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)], dtype=np.float32) * gain
        end = min(len(stereo), self.length - offset)
        self.mix[offset:offset + end] += stereo[:end]
        self.send[offset:offset + end] += stereo[:end] * reverb
        if end < len(stereo):
            self.mix[:len(stereo) - end] += stereo[end:]
            self.send[:len(stereo) - end] += stereo[end:] * reverb

    def note(self, kind, pitch, beat, duration, gain, pan=0., reverb=.16):
        if pitch == "-":
            return
        if isinstance(pitch, str):
            pitch = midi(pitch)
        self.add(voice(kind, pitch, round(duration * self.beat * RATE)), beat, gain, pan, reverb)

    def hit(self, kind, beat, gain, pan=0.):
        self.add(drum(kind), beat, gain, pan, .04 if kind == "kick" else .12)

    def render(self):
        style = self.score["rhythm"]
        quiet = style in ("gentle", "haunt", "space", "forest")
        for bar in range(32):
            section, index = divmod(bar, 8)
            prefix = "bridge_" if section == 2 else ""
            chord = [midi(n) for n in self.score[prefix + "chords"][index]]
            root = midi(self.score[prefix + "bass_roots"][index])
            melody = self.score[prefix + "melody"][index]
            beat = bar * self.meter
            energy = (0.82, 1., .90, 1.07)[section]
            lead = self.score["lead"]
            if section == 2 and style not in ("battle", "dimension"):
                lead = "keys" if lead in ("chip", "saw", "reed") else "flute"
            position = 0.
            for n, duration in melody:
                # Written rests are retained; phrase ends breathe above the groove.
                self.note(lead, n, beat + position, duration * .87, .235 * energy,
                          -.055, .25 if quiet else .16)
                if section == 3 and n != "-" and duration >= 1 and style in ("battle", "dimension", "city"):
                    self.note("flute", midi(n) - 12, beat + position, duration * .80, .043, .25, .18)
                position += duration

            # Warm, restrained chord bed; preserve space for the composed melody.
            for i, pitch in enumerate(chord):
                self.note("pad", pitch, beat, self.meter * .94, (.022 if quiet else .016) * energy,
                          (i - 1.5) * .34, .30)

            # A readable bass line anchors every harmony, with fills at phrase ends.
            if style == "waltz":
                bass_events = [(0, root, .85), (1, root + 7, .65), (2, root + 12, .65)]
            elif style in ("gentle", "space", "haunt", "forest"):
                bass_events = [(0, root, 1.75), (2, root + (7 if index % 2 else 12), 1.5)]
            elif style == "city":
                bass_events = [(0, root, .65), (1.5, root + 12, .32), (2, root, .65), (3, root + 7, .30), (3.5, root + 12, .30)]
            elif style in ("battle", "dimension"):
                bass_events = [(i * .5, root + (12 if i in (3, 7) else 7 if i == 5 else 0), .37) for i in range(8)]
            else:
                bass_events = [(0, root, .8), (1, root + 12, .6), (2, root + 7, .8), (3, root + 12, .6)]
            for at, pitch, duration in bass_events:
                self.note("bass", pitch, beat + at, duration, .16 * energy, 0, .02)

            # Broken chords develop between sections instead of looping one bar forever.
            arp_kind = "keys" if style in ("city", "waltz", "gentle") else "pluck"
            step = 1. if quiet or style == "waltz" else .5
            if style == "haunt":
                step = 2.
            for j in range(round(self.meter / step)):
                at = j * step
                pitch = chord[(j + index + (2 if section == 2 else 0)) % 4] + 12
                if pitch > 84:
                    pitch -= 12
                swing = .045 if style in ("bounce", "city") and j % 2 else 0
                gain = (.055 if quiet else .065) * energy * (.82 if j % 2 else 1)
                self.note(arp_kind, pitch, beat + at + swing, step * .68, gain, -.40 if j % 2 else .42, .30)
            if section in (1, 3) and index % 2 == 1:
                # Short reply at a phrase end, kept below the lead.
                for j in range(3):
                    self.note("bell" if quiet else "pluck", chord[(3 - j) % 4] + 12,
                              beat + self.meter - 1.5 + j * .5, .35, .042, .32, .32)

            self.groove(beat, bar, style, energy)

        # Circular ambience and delay fold all tails into the beginning of the loop.
        # Filtering runs with one second of preceding audio, preserving filter state.
        ambience = self.send.copy()
        for delay, decay in ((.053, .32), (.089, .25), (.137, .20), (.211, .17), (.307, .12), (.443, .085)):
            self.mix += np.roll(ambience[:, ::-1], round(delay * RATE), axis=0) * decay
        for repeat in (1, 2):
            self.mix += np.roll(self.send[:, ::-1], round(self.beat * .75 * RATE * repeat), axis=0) * (.20 ** repeat)
        sos = signal.butter(2, (32, 11200), "bandpass", fs=RATE, output="sos")
        extended = np.concatenate((self.mix[-RATE:], self.mix))
        mix = signal.sosfilt(sos, extended, axis=0)[RATE:].astype(np.float32)
        mix -= np.mean(mix, axis=0)
        mix *= .105 / max(float(np.sqrt(np.mean(mix ** 2))), .0001)
        mix = .88 * np.tanh(mix / .88)
        # A sub-millisecond edge taper eliminates decoder/phase rounding clicks.
        edge = 24
        ramp = np.sin(np.linspace(0, math.pi / 2, edge)) ** 2
        mix[:edge] *= ramp[:, None]
        mix[-edge:] *= ramp[::-1, None]
        voice.cache_clear()
        return mix

    def groove(self, beat, bar, style, energy):
        quiet = style in ("gentle", "haunt", "space", "forest")
        if style == "haunt" and bar % 2:
            self.hit("rim", beat + 2.5, .042 * energy, .3)
            return
        kick_gain = (.095 if quiet else .18) * energy
        for at in ([0] if quiet or style == "waltz" else [0, 2] if style != "city" else [0, 1.5, 2.75]):
            self.hit("kick", beat + at, kick_gain)
        if style == "desert":
            for at, gain in ((.75, .09), (1.5, .12), (2.5, .10), (3.25, .14)):
                self.hit("tom", beat + at, gain * energy, -.2 if at < 2 else .2)
        snare_kind = "rim" if quiet or style == "waltz" else "snare"
        for at in ([1, 2] if style == "waltz" else [2] if quiet else [1, 3]):
            self.hit(snare_kind, beat + at, (.048 if quiet else .105) * energy, .12)
        spacing = 1. if quiet or style == "waltz" else .5
        for j in range(round(self.meter / spacing)):
            at = j * spacing
            swing = .04 if style in ("bounce", "city") and j % 2 else 0
            self.hit("hat", beat + at + swing, (.030 if quiet else .063) * energy * (.75 if j % 2 == 0 else 1), -.28 if j % 2 else .28)
        if bar % 8 == 7 and not quiet:
            self.hit("open_hat", beat + self.meter - .5, .07)
            self.hit("snare", beat + self.meter - .75, .065)
            self.hit("snare", beat + self.meter - .25, .045)


def validate_score(score):
    assert 65 <= score["bpm"] <= 165
    meter = score.get("beats_per_bar", 4)
    assert meter in (3, 4)
    for prefix in ("", "bridge_"):
        for field in ("chords", "bass_roots", "melody"):
            assert len(score[prefix + field]) == 8, (score["title"], prefix + field)
        for chord in score[prefix + "chords"]:
            assert len(chord) == 4
            for n in chord:
                midi(n)
        for root in score[prefix + "bass_roots"]:
            assert 24 <= midi(root) <= 60
        for bar in score[prefix + "melody"]:
            assert abs(sum(d for _, d in bar) - meter) < .0001, (score["title"], bar)
            for n, d in bar:
                assert d > 0
                if n != "-":
                    midi(n)


def inspect_audio(path, expected_frames):
    audio, rate = sf.read(path, dtype="float32", always_2d=True)
    assert rate == RATE and audio.shape == (expected_frames, 2), (path, audio.shape)
    assert np.isfinite(audio).all()
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio ** 2)))
    seam = float(np.max(np.abs(audio[0] - audio[-1])))
    assert .05 < rms < .18 and peak < .97 and seam < .08, (path, peak, rms, seam)
    return {"seconds": round(len(audio) / rate, 3), "peak_dbfs": round(20 * math.log10(peak), 2),
            "rms_dbfs": round(20 * math.log10(rms), 2), "loop_seam_delta": round(seam, 6), "bytes": path.stat().st_size}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/audio/music")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--track", choices=IDS)
    args = parser.parse_args()
    scores = json.loads((ROOT / "tools/SlimerotMusicScore.json").read_text(encoding="utf-8"))
    assert set(scores) == set(IDS), "Slimerot score must contain exactly the 11 music IDs."
    args.output.mkdir(parents=True, exist_ok=True)
    report = {}
    preview = []
    for track in IDS:
        if args.track and args.track != track:
            continue
        score = scores[track]
        validate_score(score)
        arrangement = Arrangement(score)
        audio = arrangement.render()
        path = args.output / f"Slimerot_{track}.ogg"
        # Bounded blocks avoid large-write Vorbis encoder failures on Windows.
        print(f"Slimerot encoding {track} ({len(audio) / RATE:.1f}s)", flush=True)
        with sf.SoundFile(path, "w", samplerate=RATE, channels=2, format="OGG", subtype="VORBIS") as output:
            for offset in range(0, len(audio), 4096):
                output.write(audio[offset:offset + 4096])
        report[track] = {"title": score["title"], "bpm": score["bpm"], **inspect_audio(path, arrangement.length)}
        print(f"Slimerot {track}: {report[track]}", flush=True)
        if args.preview and track in ("bedroom", "backyard", "italian_village", "cursed_forest", "brainrot_city", "moon", "final_battle"):
            # Eight seconds from the developed A section, with separate soft edges.
            start = round(8 * arrangement.meter * arrangement.beat * RATE)
            clip = audio[start:start + 8 * RATE].copy()
            fade = np.linspace(0, 1, RATE // 3)
            clip[:len(fade)] *= fade[:, None]
            clip[-len(fade):] *= fade[::-1, None]
            preview.append(clip)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if args.preview and preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        sf.write(args.preview, np.concatenate(preview), RATE, subtype="PCM_16")


if __name__ == "__main__":
    main()
