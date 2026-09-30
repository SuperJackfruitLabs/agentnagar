#!/usr/bin/env python3
"""Writes Sample station's terminal recording, ../terminal.cast.

The recording is written by hand, here, rather than captured from a shell:
a captured session would carry the machine's real paths, user and
environment. Every byte below is invented. The session builds and tests
`tally`, the small project under ../files/: one test fails, a patch fixes
it, and the tests pass.

The output is asciicast v2: a header line, then one JSON array per event.
`o` events are terminal output; `m` markers come just before each command
is typed, so the player can stop at each one and wait for Enter.

    python3 make_terminal_cast.py           # rewrite ../terminal.cast
    python3 make_terminal_cast.py --check   # fail if it is out of date
"""

import json
import sys
from pathlib import Path

CAST = Path(__file__).resolve().parent.parent / "terminal.cast"

# 2026-09-28T09:00:00Z, the recording's invented start.
STARTED = 1790586000

ESC = "\x1b"
RESET = ESC + "[0m"
DIM = ESC + "[2m"
BOLD_GREEN = ESC + "[1m" + ESC + "[32m"
BOLD_RED = ESC + "[1m" + ESC + "[31m"
GREEN = ESC + "[32m"
RED = ESC + "[31m"
BOLD_BLUE = ESC + "[1;34m"
USER_HOST = ESC + "[1;32m"

PROMPT = USER_HOST + "sample@sample-node" + RESET + ":" + BOLD_BLUE + "/workspace/tally" + RESET + "$ "


class Cast:
    """Collects events at a running clock."""

    def __init__(self):
        self.t = 0.0
        self.events = []

    def out(self, after, text):
        self.t += after
        self.events.append([round(self.t, 3), "o", text])

    def mark(self, after, label):
        self.t += after
        self.events.append([round(self.t, 3), "m", label])

    def type(self, command):
        """Types a command a key at a time, at an uneven human pace."""
        rhythm = [0.09, 0.14, 0.07, 0.11, 0.16, 0.08, 0.12]
        for i, ch in enumerate(command):
            self.out(rhythm[i % len(rhythm)], ch)
        self.out(0.35, "\r\n")

    def lines(self, after, lines, step=0.02):
        """Prints lines, the first `after` seconds on, the rest `step` apart."""
        for i, line in enumerate(lines):
            self.out(after if i == 0 else step, line + "\r\n")


def cargo(verb, text):
    """Cargo's status lines: the verb right-aligned to 12, bold green."""
    return BOLD_GREEN + verb.rjust(12) + RESET + " " + text


def test_lines(results):
    lines = ["running %d tests" % len(results)]
    for name, ok in results:
        verdict = GREEN + "ok" + RESET if ok else RED + "FAILED" + RESET
        lines.append("test %s ... %s" % (name, verdict))
    return lines


def summary(passed, failed):
    word = GREEN + "ok" + RESET if failed == 0 else RED + "FAILED" + RESET
    return "test result: %s. %d passed; %d failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s" % (
        word,
        passed,
        failed,
    )


def empty_suite(label, target):
    return [
        cargo("Running", "%s (%s)" % (label, target)),
        "",
        "running 0 tests",
        "",
        summary(0, 0),
        "",
    ]


TESTS = [
    "blank_lines_hold_no_words",
    "counts_characters_not_bytes",
    "counts_lines_by_their_newlines",
    "counts_words_split_by_spaces",
    "counts_words_split_by_tabs",
    "empty_text_counts_nothing",
    "text_that_is_not_utf8_still_counts",
]


def build():
    cast = Cast()
    cast.out(0.0, DIM + "Sample station: a synthetic recording, not a real shell." + RESET + "\r\n")
    cast.out(0.05, DIM + "Press Enter to play the next recorded command." + RESET + "\r\n\r\n")
    cast.out(0.3, PROMPT)

    cast.mark(1.0, "cargo build")
    cast.type("cargo build")
    cast.lines(0.6, [cargo("Compiling", "tally v0.3.0 (/workspace/tally)")])
    # A long compile, cut to the player's 3 s gap when it plays.
    cast.lines(4.2, [cargo("Finished", "`dev` profile [unoptimized + debuginfo] target(s) in 4.81s")])
    cast.out(0.05, PROMPT)

    cast.mark(2.0, "cargo test")
    cast.type("cargo test")
    cast.lines(0.5, [cargo("Compiling", "tally v0.3.0 (/workspace/tally)")])
    cast.lines(1.4, [cargo("Finished", "`test` profile [unoptimized + debuginfo] target(s) in 1.38s")])
    cast.lines(0.1, empty_suite("unittests src/lib.rs", "target/debug/deps/tally-5a3e0c1f9b27d468"))
    cast.lines(0.05, empty_suite("unittests src/main.rs", "target/debug/deps/tally-0e8b4d2c71f3a956"))
    cast.lines(0.05, [cargo("Running", "tests/count.rs (target/debug/deps/count-9c1f7a3e2b5d8064)"), ""])
    cast.lines(0.05, test_lines([(name, name != "counts_words_split_by_tabs") for name in TESTS]))
    cast.lines(
        0.05,
        [
            "",
            "failures:",
            "",
            "---- counts_words_split_by_tabs stdout ----",
            "",
            "thread 'counts_words_split_by_tabs' (4817) panicked at tests/count.rs:25:5:",
            "assertion `left == right` failed",
            "  left: 1",
            " right: 3",
            "note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace",
            "",
            "",
            "failures:",
            "    counts_words_split_by_tabs",
            "",
            summary(6, 1),
            "",
            BOLD_RED + "error" + RESET + ": test failed, to rerun pass `--test count`",
        ],
    )
    cast.out(0.05, PROMPT)

    cast.mark(3.5, "patch -p1 < ../split-on-whitespace.patch")
    cast.type("patch -p1 < ../split-on-whitespace.patch")
    cast.lines(0.2, ["patching file src/lib.rs"])
    cast.out(0.05, PROMPT)

    cast.mark(1.5, "cargo test")
    cast.type("cargo test")
    cast.lines(0.5, [cargo("Compiling", "tally v0.3.0 (/workspace/tally)")])
    cast.lines(1.3, [cargo("Finished", "`test` profile [unoptimized + debuginfo] target(s) in 1.29s")])
    cast.lines(0.1, empty_suite("unittests src/lib.rs", "target/debug/deps/tally-5a3e0c1f9b27d468"))
    cast.lines(0.05, empty_suite("unittests src/main.rs", "target/debug/deps/tally-0e8b4d2c71f3a956"))
    cast.lines(0.05, [cargo("Running", "tests/count.rs (target/debug/deps/count-9c1f7a3e2b5d8064)"), ""])
    cast.lines(0.05, test_lines([(name, True) for name in TESTS]))
    cast.lines(0.05, ["", summary(7, 0), ""])
    cast.lines(0.05, [cargo("Doc-tests", "tally"), "", "running 0 tests", "", summary(0, 0), ""])
    cast.out(0.05, PROMPT)

    cast.mark(2.0, "git status --short")
    cast.type("git status --short")
    cast.lines(0.1, [" " + RED + "M" + RESET + " src/lib.rs"])
    cast.out(0.05, PROMPT)

    header = {
        "version": 2,
        "width": 80,
        "height": 24,
        "timestamp": STARTED,
        "title": "Sample station: building and testing tally",
        "env": {"SHELL": "/bin/bash", "TERM": "xterm-256color"},
    }
    lines = [json.dumps(header)] + [json.dumps(e, ensure_ascii=False) for e in cast.events]
    return "\n".join(lines) + "\n"


def main():
    text = build()
    if "--check" in sys.argv[1:]:
        if not CAST.exists() or CAST.read_text(encoding="utf-8") != text:
            print("terminal.cast is out of date; run tools/make_terminal_cast.py")
            return 1
        return 0
    CAST.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
