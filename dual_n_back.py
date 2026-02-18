import atexit
import os
import platform
import random
import shutil
import subprocess
import tempfile
import tkinter as tk
from tkinter import ttk


class LetterAudioPlayer:
    """Speaks letter stimuli through system audio with low-latency playback."""

    def __init__(self, root: tk.Tk):
        self.root = root
        self.letters = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        self.backend_name = "bell"
        self.voice_name = "default"
        self._active_process = None
        self._tmpdir = None
        self._clip_paths = {}

        if platform.system() != "Darwin":
            return

        if not shutil.which("say"):
            return

        self.voice_name = self._select_voice()

        # Pre-render clips once to improve sync against the visual flash.
        if shutil.which("afplay"):
            try:
                self._tmpdir = tempfile.TemporaryDirectory(prefix="dual_n_back_letters_")
                atexit.register(self._tmpdir.cleanup)
                self._build_letter_clips()
                self.backend_name = "afplay-clips"
                return
            except Exception:
                self._tmpdir = None
                self._clip_paths = {}

        self.backend_name = "say-live"

    def _select_voice(self) -> str:
        preferred = [
            "Ava",
            "Allison",
            "Samantha",
            "Nora",
            "Evan",
            "Moira",
            "Daniel",
        ]
        available = self._available_voices()
        for voice in preferred:
            if voice in available:
                return voice
        return preferred[0]

    def _available_voices(self):
        try:
            out = subprocess.check_output(["say", "-v", "?"], text=True, stderr=subprocess.DEVNULL)
        except Exception:
            return set()

        names = set()
        for line in out.splitlines():
            line = line.strip()
            if not line:
                continue
            names.add(line.split()[0])
        return names

    def _build_letter_clips(self):
        for idx, letter in enumerate(self.letters):
            clip = os.path.join(self._tmpdir.name, f"{idx}_{letter}.aiff")
            # Lowercase avoids phrases like "capital O".
            subprocess.run(
                ["say", "-v", self.voice_name, "-r", "185", "-o", clip, "--", letter.lower()],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self._clip_paths[idx] = clip

    def play(self, letter_index: int):
        if self._active_process and self._active_process.poll() is None:
            self._active_process.terminate()

        if self.backend_name == "afplay-clips":
            try:
                self._active_process = subprocess.Popen(
                    ["afplay", self._clip_paths[letter_index]],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                return
            except Exception:
                self.backend_name = "say-live"

        if self.backend_name == "say-live":
            try:
                self._active_process = subprocess.Popen(
                    ["say", "-v", self.voice_name, "-r", "185", "--", self.letters[letter_index].lower()],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                return
            except Exception:
                self.backend_name = "bell"

        self.root.bell()


class DualNBackApp:
    GRID_SIZE = 3

    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Dual N-Back")
        self.root.geometry("560x700")

        self.player = LetterAudioPlayer(root)

        # Game settings
        self.n_var = tk.IntVar(value=2)
        self.trials_var = tk.IntVar(value=20)
        self.stim_ms_var = tk.IntVar(value=700)
        self.pause_ms_var = tk.IntVar(value=1800)

        # Runtime state
        self.trial_index = -1
        self.running = False
        self.history = []
        self.responses = []
        self.current_pos = None
        self.current_letter = None
        self.awaiting_response_for = None
        self.hide_job = None
        self.next_job = None

        # Scoring
        self.pos_hits = 0
        self.pos_misses = 0
        self.pos_false = 0
        self.aud_hits = 0
        self.aud_misses = 0
        self.aud_false = 0

        self._build_ui()
        self.root.bind("<KeyPress-f>", self.on_position_key)
        self.root.bind("<KeyPress-j>", self.on_audio_key)

    def _build_ui(self):
        frame = ttk.Frame(self.root, padding=14)
        frame.pack(fill="both", expand=True)

        title = ttk.Label(frame, text="Dual N-Back", font=("Helvetica", 20, "bold"))
        title.pack(anchor="center", pady=(0, 8))

        instructions = ttk.Label(
            frame,
            text="F = position match   |   J = spoken-letter match",
            font=("Helvetica", 11),
        )
        instructions.pack(anchor="center", pady=(0, 10))
        audio_backend = ttk.Label(
            frame,
            text=(
                f"Audio backend: {self.player.backend_name} ({self.player.voice_name})"
                if self.player.backend_name in {"afplay-clips", "say-live"}
                else f"Audio backend: {self.player.backend_name}"
            ),
            font=("Helvetica", 10),
        )
        audio_backend.pack(anchor="center", pady=(0, 10))

        settings = ttk.LabelFrame(frame, text="Settings", padding=10)
        settings.pack(fill="x", pady=(0, 12))

        ttk.Label(settings, text="N level:").grid(row=0, column=0, sticky="w", padx=4, pady=4)
        ttk.Spinbox(settings, from_=1, to=5, textvariable=self.n_var, width=6).grid(
            row=0, column=1, sticky="w", padx=4, pady=4
        )

        ttk.Label(settings, text="Trials:").grid(row=0, column=2, sticky="w", padx=4, pady=4)
        ttk.Spinbox(settings, from_=8, to=100, textvariable=self.trials_var, width=8).grid(
            row=0, column=3, sticky="w", padx=4, pady=4
        )

        ttk.Label(settings, text="Stimulus ms:").grid(row=1, column=0, sticky="w", padx=4, pady=4)
        ttk.Spinbox(settings, from_=300, to=2000, increment=50, textvariable=self.stim_ms_var, width=8).grid(
            row=1, column=1, sticky="w", padx=4, pady=4
        )

        ttk.Label(settings, text="Cycle ms:").grid(row=1, column=2, sticky="w", padx=4, pady=4)
        ttk.Spinbox(settings, from_=800, to=3000, increment=50, textvariable=self.pause_ms_var, width=8).grid(
            row=1, column=3, sticky="w", padx=4, pady=4
        )

        self.start_btn = ttk.Button(settings, text="Start", command=self.start_game)
        self.start_btn.grid(row=0, column=4, rowspan=2, padx=8)

        self.canvas = tk.Canvas(frame, width=420, height=420, bg="#fafafa", highlightthickness=1)
        self.canvas.pack(pady=(2, 10))

        self.cells = []
        self._draw_grid()

        self.status_var = tk.StringVar(value="Press Start to begin")
        self.status_label = ttk.Label(frame, textvariable=self.status_var, font=("Helvetica", 11))
        self.status_label.pack(anchor="center", pady=(0, 8))

        self.score_var = tk.StringVar(value="")
        self.score_label = ttk.Label(frame, textvariable=self.score_var, font=("Helvetica", 11))
        self.score_label.pack(anchor="center")

    def _draw_grid(self):
        self.cells.clear()
        margin = 22
        size = (420 - margin * 2) / self.GRID_SIZE

        for r in range(self.GRID_SIZE):
            for c in range(self.GRID_SIZE):
                x0 = margin + c * size
                y0 = margin + r * size
                x1 = x0 + size - 8
                y1 = y0 + size - 8
                rect = self.canvas.create_rectangle(
                    x0,
                    y0,
                    x1,
                    y1,
                    fill="#e8ecf0",
                    outline="#9aa3ab",
                    width=2,
                )
                self.cells.append(rect)

    def start_game(self):
        if self.running:
            return

        n = self.n_var.get()
        trials = self.trials_var.get()
        stim_ms = self.stim_ms_var.get()
        cycle_ms = self.pause_ms_var.get()

        if n < 1 or trials < n + 2:
            self.status_var.set("Choose valid settings: trials should be at least N + 2")
            return
        if stim_ms >= cycle_ms:
            self.status_var.set("Cycle ms must be greater than stimulus ms")
            return

        self.running = True
        self.trial_index = -1
        self.history = []
        self.responses = []
        self.current_pos = None
        self.current_letter = None
        self.awaiting_response_for = None

        self.pos_hits = self.pos_misses = self.pos_false = 0
        self.aud_hits = self.aud_misses = self.aud_false = 0

        self._clear_highlight()
        self.start_btn.state(["disabled"])
        self.status_var.set("Game running. Use F and J during each trial.")
        self._update_score_text(live=True)

        self._schedule_next_trial(10)

    def _schedule_next_trial(self, delay_ms: int):
        if self.next_job is not None:
            self.root.after_cancel(self.next_job)
        self.next_job = self.root.after(delay_ms, self.next_trial)

    def next_trial(self):
        if not self.running:
            return

        # Grade the previous trial after response window closes.
        if self.awaiting_response_for is not None:
            self._grade_trial(self.awaiting_response_for)

        self.trial_index += 1
        if self.trial_index >= self.trials_var.get():
            self.finish_game()
            return

        total_cells = self.GRID_SIZE * self.GRID_SIZE
        self.current_pos = random.randrange(total_cells)
        self.current_letter = random.randrange(len(self.player.letters))

        self.history.append((self.current_pos, self.current_letter))
        self.responses.append({"pos": False, "aud": False})
        self.awaiting_response_for = self.trial_index

        self._show_stimulus(self.current_pos)
        self.player.play(self.current_letter)

        n = self.n_var.get()
        can_match = self.trial_index >= n
        self.status_var.set(
            f"Trial {self.trial_index + 1}/{self.trials_var.get()}"
            + (" (match possible)" if can_match else "")
        )

        stim_ms = self.stim_ms_var.get()
        cycle_ms = self.pause_ms_var.get()

        if self.hide_job is not None:
            self.root.after_cancel(self.hide_job)
        self.hide_job = self.root.after(stim_ms, self._clear_highlight)

        self._schedule_next_trial(cycle_ms)

    def _show_stimulus(self, pos: int):
        self._clear_highlight()
        self.canvas.itemconfig(self.cells[pos], fill="#f9a03f")

    def _clear_highlight(self):
        for rect in self.cells:
            self.canvas.itemconfig(rect, fill="#e8ecf0")

    def on_position_key(self, _event=None):
        if not self.running or self.awaiting_response_for is None:
            return
        self.responses[self.awaiting_response_for]["pos"] = True
        self._update_score_text(live=True)

    def on_audio_key(self, _event=None):
        if not self.running or self.awaiting_response_for is None:
            return
        self.responses[self.awaiting_response_for]["aud"] = True
        self._update_score_text(live=True)

    def _grade_trial(self, idx: int):
        n = self.n_var.get()
        if idx < n:
            return

        curr_pos, curr_letter = self.history[idx]
        back_pos, back_letter = self.history[idx - n]

        pos_target = curr_pos == back_pos
        aud_target = curr_letter == back_letter
        pos_pressed = self.responses[idx]["pos"]
        aud_pressed = self.responses[idx]["aud"]

        if pos_target and pos_pressed:
            self.pos_hits += 1
        elif pos_target and not pos_pressed:
            self.pos_misses += 1
        elif not pos_target and pos_pressed:
            self.pos_false += 1

        if aud_target and aud_pressed:
            self.aud_hits += 1
        elif aud_target and not aud_pressed:
            self.aud_misses += 1
        elif not aud_target and aud_pressed:
            self.aud_false += 1

        self._update_score_text(live=True)

    def _update_score_text(self, live: bool):
        pos_line = f"Position  H:{self.pos_hits}  M:{self.pos_misses}  FA:{self.pos_false}"
        aud_line = f"Audio     H:{self.aud_hits}  M:{self.aud_misses}  FA:{self.aud_false}"

        if live:
            trial_text = ""
            if self.awaiting_response_for is not None and self.running:
                resp = self.responses[self.awaiting_response_for]
                trial_text = (
                    f" | Current trial response: F={'Y' if resp['pos'] else 'N'} J={'Y' if resp['aud'] else 'N'}"
                )
            self.score_var.set(pos_line + "\n" + aud_line + trial_text)
        else:
            self.score_var.set(pos_line + "\n" + aud_line)

    def finish_game(self):
        if self.awaiting_response_for is not None:
            self._grade_trial(self.awaiting_response_for)
            self.awaiting_response_for = None

        self.running = False
        self._clear_highlight()
        self.start_btn.state(["!disabled"])

        total_scored = max(0, self.trials_var.get() - self.n_var.get())
        pos_score = self.pos_hits - self.pos_false
        aud_score = self.aud_hits - self.aud_false
        combined = pos_score + aud_score

        self.status_var.set(
            f"Finished. Scored trials: {total_scored}. "
            f"Position score: {pos_score}, Audio score: {aud_score}, Combined: {combined}"
        )
        self._update_score_text(live=False)


def main():
    root = tk.Tk()
    app = DualNBackApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
