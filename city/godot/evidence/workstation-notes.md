# Workstation evidence (interactions Part B)

Screenshots, measured numbers and the privacy proof for the station
computer: `Use computer` on a workshop or reading-room desk, or `Look at
screen` behind one an agent already sits at. The
[interactions design](../../../docs/superpowers/specs/2026-09-27-city-interactions-design.md)
specifies it (§4–§5); its §10 amendments record what the build decided.
The `city/README.md` section "Station computer" is the player-facing
summary this notes file backs up.

## What Part B delivers

- **A real computer, in Sample mode by default.** Every workstation opens
  a full-screen station computer skinned in the current style's monitor
  bezel — a badge, the station's name, a dock of seven apps and "Stand
  up" — playing a recorded station bundled with the client
  (`godot/sample_station/`). It needs no account and is synthetic: a
  build and test run in the terminal, an ACP chat transcript with a
  permission request, a file tree, a log tail, a health series, a diff,
  and one board with a pending gate and question.
- **Seven apps:** Terminal (a VT100 grid over `vt100` via `TermGrid`),
  Chat (ACP, with permission requests and elicitation), Files (a lazy
  tree with a text/binary preview), Logs (a search over a live tail),
  Health (readings plus Start/Stop/Restart), Changes (a diff viewer) and
  Work (a station's Superpipeline cards, gates and questions).
- **Live mode**, off by default and desktop-only, opens the player's own
  AgentPod stations the same way `apn fleet login` signs in: PKCE through
  a loopback listener and the system browser, a 90-day device credential,
  five-minute tokens. Real operations (Stop, Restart, Start, a gate's
  reject/request-changes, a chat mode switch to `full-auto`) ask for
  confirmation and name the station or board.
- **The in-world monitor**, `core/station/monitor.gd`, shows the same
  screen through a `SubViewport` at 10 Hz for the player's own desk while
  seated, or while watching within 4 m; every other desk shows a static
  "idle" or "in use" texture. Pixel art shows the in-use glow, brightened
  by the activity pulse, on the player's own desk instead of a feed (see
  "Known limits" and the spec's §10 amendment).
- **"Look at screen"** opens the same computer read-only over an
  occupied desk's shoulder: input is off, the badge says "Watching", and
  in live mode it needs a bound desk the player's own token can see.
- **Disconnect**, offered wherever a credential is held, forgets it
  locally at once and revokes the device on the hub with a fresh human
  token from its own browser sign-in (the device's own token cannot
  revoke itself — the hub refuses it on that route).
- **Privacy** (spec §1 criterion 6): station content and credentials
  never reach the city core, the bridge, projections, the input log,
  replays, `print`/`push_warning`/`push_error`, the client's log file, or
  a city server. See "The privacy proof" below.

## Screenshots

All captured at 1280×800 with the probes below, viewed before committing,
and named `workstation-*.png`. None shows real station data: everything
here is Sample station's synthetic recording, or fixture agents that
carry no real agent state.

- **`workstation-bezel-<style>.png`** (all six styles): the computer's
  desktop — badge, station name, the seven-app dock, "Stand up" — showing
  each style's own monitor frame (flat in lowpoly, an inked line in
  anime, a wood frame in solarpunk, a glass edge in neon, a chunky navy
  case in voxel, a pale CRT case in pixel art, each in its own pixel-font
  or body face).
- **`workstation-app-<app>-<style>.png`** (Terminal, Chat, Files, Logs,
  Health, Changes, Work; lowpoly_tropical and pixel_art): each app in
  Sample mode. Terminal is played a few lines in (`cargo test`'s output,
  then `git status --short`) rather than shot at its unplayed "press
  Enter" banner; Files has `Cargo.toml` selected so the preview shows
  text rather than "Choose a file to preview it."
- **`workstation-monitor-idle-<style>.png`**,
  **`workstation-monitor-in-use-<style>.png`**,
  **`workstation-monitor-live-<style>.png`** (the player's own desk, its
  monitor showing the feed — or, in pixel art, the glow — through the
  bezel from behind the chair) and
  **`workstation-monitor-mixed-night-<style>.png`** (the player's own
  desk live, one neighbour in use, another idle, at night): all six
  styles.
- **`workstation-watch-look-at-screen.png`**: "Look at screen" behind a
  fixture agent seated at a workshop desk (Sample mode; lowpoly_tropical)
  — the "Watching" badge, "Stop watching" in place of "Stand up", and
  Chat's transcript (Terminal would still show its unplayed banner, since
  watch mode's input is read-only and can never press Enter to play it).

### Capturing

Two probes under `city/godot/tools/probes/`, in the pattern Part A's
`capture_interact.gd` and Task 11's `capture_workstation.gd` set:

- **`capture_workstation.gd`** (Task 11): the in-world monitor shots
  (`idle`, `in-use`, `in-use-night`, `live`, `mixed-night`, and the raw
  feed texture), one style a run.
  ```sh
  godot --path city/godot --resolution 1280x800 \
    --script res://tools/probes/capture_workstation.gd -- \
    out=$HOME/.cache/agentnagar-t12-monitor style=lowpoly_tropical
  ```
- **`capture_station_ui.gd`** (new, Task 12): the computer's own screen —
  the desktop/bezel, each app in turn (`mode=apps`), or "Look at screen"
  behind a fixture agent found by crowding the district (`mode=watch`).
  ```sh
  godot --path city/godot --resolution 1280x800 \
    --script res://tools/probes/capture_station_ui.gd -- \
    out=$HOME/.cache/agentnagar-t12 style=lowpoly_tropical mode=apps
  godot --path city/godot --resolution 1280x800 \
    --script res://tools/probes/capture_station_ui.gd -- \
    out=$HOME/.cache/agentnagar-t12 style=lowpoly_tropical mode=watch
  ```

Godot is a Flatpak here and cannot see the host's `/tmp`, so every
capture went to `~/.cache/agentnagar-t12*/` and was copied into this
folder afterward, renamed to `workstation-*`.

## Test counts

- **The Godot suite:** `godot --path . --script res://tests/run_all.gd`
  gives **895/895**, the count Task 11's fix round left it at; this task
  added no game code, only a capture probe and docs, and re-ran the
  suite unchanged (below). It grew from Part A's close of 669/669 across
  Tasks 1–11 as each task's own tests landed; `progress.md` (the ledger)
  has the count after every task and fix round. The final fix wave added
  11 tests: **906/906**.
- **`cargo test --workspace`:** **500 passed**, 0 failed (Rust core,
  contracts, CLI, MCP and `city-godot`'s own unit tests; term.rs's
  `vt100`-backed grid is part of this count).
- **The style kits:** `python3 -m unittest tools/styles/*/test_*.py`,
  **125 tests across 8 files**, all passing: lowpoly 17, anime 14,
  solarpunk 15, neon 15, voxel 25, pixel 26, the shared tram layout 4,
  the shared UI frames 9. Where Blender is installed, the byte-for-byte
  rebuild tests and the Khronos glTF validator run and pass too.
- **The workstation's own test files,** at their final size: privacy's
  `test_station_privacy.gd` (4 tests: the full live-session walk with
  planted markers, live watch sending nothing, watch offered only where
  the source can see the station, plus the static/`user://` scans it
  shares with `computer_screen`/`credential`/`interact` tests);
  `test_monitor.gd` (13, the in-world monitor and its 10 Hz update, the
  4 m watch radius, the activity pulse, and pixel art's own-desk glow);
  `test_station_apps.gd` (the seven apps' behaviour, including the
  200 KB terminal burst and the 1 MiB preview below).

## Measured numbers, from the task reports

- **Terminal burst:** a 200 KB write completes in **11.3 ms over 11
  frames** (budget 400 ms × `machine_factor()`) — Task 6's fix round.
  Output is collected as it arrives and fed to the grid once a frame, so
  a burst of small writes costs one parse and one diff per frame, not
  one per write.
- **The 1 MiB file/diff preview:** placed over **65 frames**, worst
  frame **5.7 ms in Files** and **4.9 ms in Changes** (budget 16 ms ×
  `machine_factor()`) — Task 6. A single line over 4,000 characters is
  cut for display ("… (line cut)"), since the preview is read-only and a
  minified 1 MiB line would stall a frame.
- **Chat, a long session:** 780 events taken in 1.6 ms, drawn over 12
  frames, worst frame **9.8 ms** (budget 16 ms) — Task 7. A 64 KiB
  streamed reply, drawn one 256-character chunk a frame, fell from a
  worst frame of **25.9 ms** to **7.1 ms** once a bubble holds one label
  a paragraph instead of rewriting the whole text every chunk — Task 7's
  fix round.
- **The frame A/B** (Task 11, recorded evidence, not a gate — thermal
  variance on the bench laptop exceeds the ±5% the ruling allows for):
  the workshop scene, 60 agents, eight screens in use, BASE (before
  Task 11's art) against HEAD, GPU ≤ 45 °C, two rounds each direction.
  Every style's frame p50 was within **±1%** of BASE, well inside the
  ±5% margin and far from the 10% line that would have blocked the
  build: lowpoly −0.6%, anime +0.5%, solarpunk 0.0%, neon −0.4%, voxel
  +0.3%, pixel +1.0%.

## The privacy proof

Spec §1's sixth success criterion: station content and credentials never
reach the city core, its input log, replays, projections, the network
server, logs, or crash reports (the city has none — see "Known limits").
`tests/test_station_privacy.gd`'s
`test_a_live_session_leaves_nothing_of_the_station_in_the_city` (Task
10) proves it end to end:

- A **recording bridge** stands in for `CityWorld` in both the driver's
  and the player's hands, recording every call, its arguments and its
  answer.
- **Unique markers** (`PRIV<WHAT><random hex>`) are planted in the
  station's name and purpose, terminal output and typed input, a chat
  reply and a typed prompt, a file's name and contents, a log line, a
  diff and its path, a card's title and activity, a question's answer
  and a gate's comment, a 502 body, malformed frames, and a malformed
  address — plus the fake hub's tokens, device secrets and sign-in
  codes, forbidden as strings in their own right.
- The player then uses every app for real: types in the terminal and
  receives malformed frames; sends a chat prompt and answers a
  permission request; hits a 401 on Files (retried); reads the Logs
  tail; hits a 502 on Health; reads the Changes diff; in Work, links the
  agent, approves a gate with a comment, answers a question, and rides
  out two Superpipeline 401s and a malformed address.
- **What the test checks:** the city hears only `Use` and `StopUsing` —
  nothing while the computer is open. None of the forbidden strings
  appears in any bridge call, argument or answer; the input log;
  `replay_json`; the public, Asha's or the player's own projection;
  anything printed or pushed as a warning/error in-process; or any file
  under `user://logs`. Every network connection the station code made is
  matched to one request the fake hub received — nothing reached
  anywhere else. A byte-for-byte comparison session (live mode off,
  nothing done on the computer, stepped tick for tick) produces an
  **identical** input log, `replay_json` and set of projections: what
  everyone else sees of the player is `using {target: "seat:rw1",
  capability: "use", anchor: 1}` either way.
- A companion test, `test_watching_a_bound_desk_live_sends_nothing`,
  proves the same for live watch: no terminal or board frame, no chat
  session POSTed (only `subscribe`), no city command, while the player
  types, sends, pastes, switches chat modes, tries Stop/reject/answer,
  and moves — closing by itself when the watched occupant stands up.
- Two static checks back the runtime proof: a scan of `core/station/`'s
  source (comments and literals stripped) that nothing there names or
  reaches `CityWorld`, `WorldDriver` or the scene tree's root except to
  send `Use`/`StopUsing`; and a byte scan of every file under `user://`
  (excluding already-scanned logs and the renderer's own shader cache)
  for this run's markers.

## Known limits (deferred, from the ledger)

Recorded in `progress.md` as "minor (deferred)": real, understood, and
left for later rather than blocking Part B.

- **Underscore-prefixed members** are read across the controller/main
  boundary; `capture_mouse_fn` lacks an `is_valid` guard (Task 1).
- **Placeholder art** (pixel art, voxel) showed no monitor cue before
  Task 11 landed the real art; that gap is closed.
- **`sample_source.gd`** was 956 lines before Task 4's fix round split
  it; the split landed, so this is historical.
- **`test_sample_station.gd`**'s failure message names six helpers where
  there are seven (Task 4).
- **`TermGrid`'s resize** has no first-party test for a resize after
  scrolling back (verified safe against `vt100` 0.16.2's source);
  `Grid::resize` does not re-read `scrollback_offset`, latent only if
  `vt100` changes it (Task 3).
- **"Use computer"** stays offered for one tick after F10 reopens and
  immediately closes it — harmless (Task 5).
- **Watching with no session** shows "No session" until Chat is reopened
  — it does not poll for a session that starts later (Task 7).
- **No in-game Cancel** while Disconnect's revoke browser trip is open
  (`cancel_browser()` exists as a seam, unused); the private directory
  `user://.station_private/` is created but stays empty (Task 8).
- **Two credential replacements in a row** lose the older flow's note; a
  log line over 64 KiB swallows events before its newline (Task 8).
- **A stale "as good as revoked" comment;** the fake hub's device-list
  rows omit `lastUsedAt` and keep `revoked`/`revokedAt` as two separate
  fields; a retiring credential's late note can overwrite `SIGNING_IN`;
  a sign-in cancelled mid device-mint may leave an unnamed device (Task
  8).
- **`computer_screen` lists live stations on every open,** beyond the
  once-per-sign-in listing the ruling settled on — extra requests, not a
  correctness gap.
- **During a reconnect's pre-attach window,** the terminal shows
  "offline" while the new socket is already open, and input typed then
  is held and sent on attach rather than refused — the label lags the
  real state by one window (Task 9). Typing while offline/connecting
  also scrolls the terminal to the bottom.

None of these touch privacy, determinism or the collision/door gates;
each is a small UX or bookkeeping gap the ledger's rulings chose to
accept rather than block the build over.

## The manual live session — not done

**This has not been run.** Every automated check above uses the fake
hub (Task 8) on `127.0.0.1`, never a real one. No one has signed the
client into a real AgentPod hub and used a real station's terminal,
chat, files, logs, health, changes or Work through it.

Running it needs, in order:

1. **The operator's authorization** to run a live session against their
   own development hub and board — this is a real operation, not a test,
   and is not implied by anything in this repository.
2. **The `agentnagar` OAuth client registered on that hub**
   (`HUB_OAUTH_CLIENTS`), with a loopback redirect and audiences naming
   both the hub itself and Superpipeline. Without the hub named as its
   own audience, every call to the hub fails, signing in included, not
   only Disconnect's revoke: the hub checks each token's audience
   against its own address.
3. **The internal SJL decision** (spec §5.6: "the city client is a
   first-party human client of the suite issuer") accepted — live mode
   stays off by default until it is.

Until all three hold, live mode is exercised only against the fake hub,
and the plan's own release notes must say plainly that the manual live
session has not been performed.

The fake hub is not generated from AgentPod's or Superpipeline's
contract packages. It mirrors the named handlers of AgentPod at
`9bc1997` and Superpipeline at `d53992f`. The routes changed in the
final fix wave name, in a comment, the handler they mirror
(`<repo>@<sha>:<path>`); the older routes do not yet. The final
review found three places where it had drifted from them (a concurrent
session POST, a socket token refused before the upgrade, a chat through
a node outage); the final fix wave brought each back to the real
handler, but a fake is only as right as the last time it was read
against the source.

### Before live mode ships

The manual, authorized live session of spec §7 is **required before
live mode is enabled** — before the `live` setting is turned on by
default, offered as ready, or described in release notes as working. The
automated suite proves the client against the fake alone; only that
session proves it against a real hub and board.
