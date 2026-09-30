# City interactions, Part B (the workstation): implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A workstation in the city is a real computer onto an AgentPod station. Anyone can sit at one and use **Sample station**, a recording that behaves like the real thing. A signed-in player can open their own stations: a terminal, the agent's chat with permission answers, files, logs, health, changes and lifecycle, plus that agent's Superpipeline cards, gates and questions. Live mode stays behind a setting that is off by default.

**Architecture:**

- **The desk.** A new `workstation` kind is a `seat`-class desk. It has a `sit` anchor, a `use` anchor at the same point, a `display` anchor and a `stand` anchor.
  - `Use {capability: "use"}` on a workstation takes the seat under the seat rules and records `using`.
  - Other viewers see only "at a workstation" and a monitor drawn in use.
- **The computer.** It is a `Screen` on the screen stack, `core/station/computer_screen.gd`. It holds a desktop, a dock and seven apps, each the city-styled counterpart of a console tab.
- **One source interface.** Every app talks to a `StationSource`, which has two implementations:
  - `SampleSource` plays the bundled recording;
  - `LiveSource` calls AgentPod's hub and Superpipeline's API over `HTTPClient` and `WebSocketPeer`, as the player's own client.
- **The terminal grid** comes from Rust: `TermGrid` in `city-godot`, wrapping the `vt100` crate.
- **Privacy.** Station content never reaches the city core, bridge, logs or any city server. A planted-marker test checks every channel.

**Tech Stack:**
- Rust: `city-godot` and the new `vt100` dependency, `city-core`, `city-contracts`.
- Godot 4.6.3 GDScript: `HTTPClient`, `WebSocketPeer`, and `TCPServer` for the fake hub and the sign-in callback.
- The Python and Blender kit builders under `city/tools/styles/`.

**Spec:** `docs/superpowers/specs/2026-09-27-city-interactions-design.md`, Part B (§4–§6, §7's Part B tests, §8, §9), with **§10's "found while planning Part B" amendments**, which this plan's commit adds. Part A's §10 amendments hold, especially:
- the anchor-facing convention;
- "any new Use ends the one under way";
- `inspect` being client-only.

**Protocol reference:** `.superpowers/interactions/protocols.md`, pinned at AgentPod `9bc1997` and Superpipeline `d53992f` and dated 2026-09-29. It is a git-ignored working file, and each task's brief says which sections to read. Every request, frame and error below matches it. Where the spec's §5.1 (at `d4dc301e`/`91c3ba7`) differs, the amendments and this plan win.

## Global Constraints

- **Worktree.** Work in a dedicated worktree (`agentnagar-workstation`), on branch `feat/city-workstation`, cut from `feat/city-interactions` after Part A's final fix wave. Never use a bare `git stash`.
- **Commit messages** end with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01JKP5riujFNbo1iL4Yjv4qQ
  ```
- **Checks,** from `city/`, after every task:
  - `cargo fmt --all --check`
  - `cargo clippy --workspace --all-targets -- -D warnings`
  - `cargo test --workspace`
  - `cargo build -p city-core --target wasm32-unknown-unknown`
  - `python3 fixtures/district/generate.py --check`
  - the kit tests
  - after Rust changes, `scripts/build-godot.sh`
  - the Godot suite from `city/godot`: `godot --headless --path . --script res://tests/run_all.gd`, with Part A's final count as its baseline

  The collision audit stays at 0 in all six styles, and door entry stays at 100%.
- **Determinism:**
  - no floats in the core's rules;
  - no new RNG draws;
  - `Use` of a workstation replays byte-identically;
  - agents never send `Use`, so the district replay pin changes only where the fixture changes.
- **Privacy (spec §1, criterion 6):** these may not reach the city core, the bridge, projections, the input log, replays, `print`/`push_warning`/`push_error`, the client's log file, the error watch, or anything addressed to a city server:
  - station content: terminal bytes, chat, file names and contents, logs, diffs, board data;
  - credentials and tokens.

  Code in `core/station/` never calls `CityWorld` except to send `Use`/`StopUsing`, and never logs a response body.
- **Nothing live in tests.** Automated tests use the fake hub (Task 8) on `127.0.0.1` with an ephemeral port, and never reach a real hub, Superpipeline or the network. Tests never write the real `user://settings.cfg` or the real credential file.
- **Live mode is off by default:** the `station.live` setting is `false`.
  - With it off, no code path opens a network connection. Every desk opens Sample station.
  - With it on, the desktop offers "Connect your AgentPod".
- **Live mode is desktop-only in this plan.** Sign-in needs a loopback listener, which web and mobile exports cannot open. There, "Connect your AgentPod" says "Sign-in needs the desktop app for now", and the source stays Sample.
- **Real operations are marked real (spec §5.5).** These ask for confirmation, naming the station or board:
  - Stop, Restart, Start;
  - gate "reject" and "request changes";
  - a chat mode switch to `full-auto`.

  Live mode shows a "Live" badge and the station's name on the bezel. The first terminal opened in a session shows a one-line notice that it is a real shell.
- **Leaving:**
  - F10, the bezel's "Stand up", and controller B held for **0.5 s** always leave;
  - Esc leaves, except while the terminal or a text field has focus.
- **Values (spec §5):**
  - the terminal is at least 80×24 and resized to fit;
  - the in-world monitor updates at **10 Hz**, only for the player's own desk while seated, or while watching within **4 m**.
- **Code voice:**
  - plain-sentence doc comments;
  - tabs in GDScript, rustfmt in Rust;
  - names spelled out;
  - comments say why.

## Review Focus

1. **The five-minute token expires while the player is working.** The terminal, the chat and the board stream keep working, because the client re-exchanges the device credential before expiry and reconnects the sockets. The player never sees a sign-in prompt unless the device credential itself is refused. Task 8 tests this on a 2-second fake-hub lifetime.
2. **The node goes offline mid-session.** Every app shows "Station offline" instead of an error dump or a spinner forever. The terminal and chat reconnect with backoff when the node returns, and the chat replays from its last `seq` without duplicates. Task 9 tests this.
3. **Keys meant for the computer leak into the game.** Typing W, A, S, D, E, Space, Tab, M or Esc in the terminal or chat never moves the player, cycles a verb, opens the map or leaves. F10 and a 0.5 s B hold always leave. Task 5 tests this.
4. **A marker string planted in station content turns up somewhere else.** It must not appear in the core's input log, projections, replay, the client log, the error watch, bridge calls, or a would-be city-server payload, including on error paths such as a 401, a 502 or a malformed frame. Task 10 tests this.
5. **Two players at adjacent desks, or an agent at its own desk.** Other viewers see "at a workstation" and a glowing monitor, and nothing else. Standing behind an occupied desk offers "Look at screen" only where the viewer's source can see that station. In sample mode, that means only the desks where an agent sits. Tasks 2 and 10 test this.

---

### Task 1: Take the interaction orchestration out of `main.gd`

**Why first:** Part A's final review found about 250 lines of interaction orchestration in `main.gd`, and `current_target()` running twice a frame. The workstation adds more overlays and a hand-off, so this code gets its own home first. The move is behaviour-preserving.

**Files:**
- a new `city/godot/core/interaction_controller.gd`
- `main.gd`
- tests: `tests/test_interact.gd`, `tests/test_main.gd` (unchanged in intent), and a new cache test

**Interfaces:**
- **`InteractionController`** (a `RefCounted` owned by `main.gd`) takes over these, with the same behaviour:
  - `choice()` and `current_target()`;
  - `_act`, `_follow_reading`, `_open_panel`;
  - `panel_of`, `source_of`, `displays`;
  - the surface focus.

  `main.gd` calls `controller.frame(delta, view_state)` once a frame, then reads `controller.target` and `controller.prompt`.
- **The target is computed once a frame** and cached until the next `frame()`. `choice()` and the surface target read the cache.
- **The hook for Task 5:** `signal use_began(target: Dictionary, capability: String)`, fired when the core confirms a `using` whose capability is not `sit` or `read`.

- [ ] **Step 1: Write the failing tests.**
  - `current_target` is computed once per frame, however many readers call it; count calls through a test hook.
  - The existing interaction, prompt, reading and tram-precedence tests pass against the controller.
- [ ] **Step 2: Move the code.** Keep every behaviour, and record the lines removed from `main.gd` in the report.
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `refactor(city): an interaction controller of its own`.

---

### Task 2: The workstation kind, the desks, and using one

**Files:**
- `city/catalogue/catalogue.json`
- `city/fixtures/district/generate.py`, and `manifest.json` regenerated
- `city/crates/city-core/src/interact.rs`, and `project.rs` if needed
- tests: `interact.rs` unit tests, `tests/interact.rs`, the fixture tests
- `city/godot/core/interact.gd` (verbs), and a placeholder workstation in every style so the suite stays green

**Interfaces:**
- **The `workstation` kind:**
  - `class: "seat"`, the same footprint as `desk`, height 75;
  - anchors:
    - `0` `sit` at (0, 0), facing 0;
    - `1` `use` at (0, 0), facing 0;
    - `2` `display` on the desk's far edge, facing toward the chair;
    - `3` `stand` 60 cm behind the chair, facing the monitor;
  - capabilities: `sit` at sit, `use` at use, `watch` at stand, and `inspect`;
  - `name` "Workstation", `description` "A desk with a computer on it."

  `watch` is client-only, like `inspect`: the core refuses it with `NoSuchCapability`, and the client never sends it.
- **The fixture:**
  - the workshop's eight `desk` seats become `workstation` seats, all hot desks (no binding), with pods and Kai's reservation unchanged;
  - the reading room gains two `workstation` seats, `seat:rw1` and `seat:rw2`, as public hot desks, reachable, with the room's capacity unchanged.
- **The core, `Use {capability: "use", anchor: 1}` on a workstation seat:**
  - takes the seat under the seat rules: reservation, capacity, pods, and `NotYourSeat` for a hidden observer;
  - records `using {target, capability: "use", anchor: 1}`;
  - emits `Seated` and then `Using`.

  From `sit` on the same seat to `use`, or back, is a switch:
  - `using` changes and `StoppedUsing`/`Using` fire;
  - there is **no** `SeatReleased` or `Seated` churn, and the seat stays held.

  The `sit` and `use` anchors are one place: whoever holds one holds both.
- **Agents** seated at a workstation by the policy keep `using {capability: "sit"}`, and their events are unchanged.
- **The client verbs.** A workstation offers "Use computer" (`use`), then "Sit", then "Inspect". While using, "Stand up" is the stop verb. From the `stand` anchor, an occupied workstation offers "Look at screen" (`watch`); Task 5 opens it.
- **Other viewers** get the name tag suffix "· at a workstation" for `using.capability == "use"`.

- [ ] **Step 1: Write the failing tests.**
  - The catalogue contract for `workstation`.
  - The fixture: the workshop's seats are workstations, the reading room has two, and every anchor is reachable.
  - Core:
    - Use `use` takes the seat;
    - a reserved seat is refused to others;
    - sit→use and use→sit on one seat produce no seat churn;
    - a second person's Use of either anchor is refused `AnchorTaken`;
    - `watch` is refused;
    - every release path clears `using`;
    - a replay with workstation Use commands is byte-identical.
  - Client: verbs and their order, "· at a workstation" on the name tag, and "Look at screen" offered only from the stand anchor of an occupied desk.
- [ ] **Step 2: Implement it, and regenerate the fixture.** Re-pin the district replay hash, justified the way Part A justified its re-pin: the new code on the old manifest reproduces the old hash.
- [ ] **Step 3: Draw a placeholder workstation in every style,** fitting its footprint so the collision audit stays at 0. The desk art may reuse `desk`'s, with a box for the monitor. Task 11 draws the real one.
- [ ] **Step 4: Run the checks.**
- [ ] **Step 5: Commit:** `feat(city): workstations to sit and work at`.

---

### Task 3: `TermGrid`, a terminal grid from Rust

**Files:**
- `city/crates/city-godot/Cargo.toml` (adds `vt100`, the latest 0.15.x; check that it builds for `wasm32-unknown-unknown` and for the emscripten web build)
- a new `city/crates/city-godot/src/term.rs`
- `lib.rs` (registers the class)
- tests: unit tests in `term.rs`, and `godot/tests/test_term_grid.gd`

**Interfaces:**
- **The class:** `TermGrid` (`#[class(init, base = RefCounted)]`), with these functions:
  - `setup(cols: i32, rows: i32)`
  - `feed(bytes: PackedByteArray)`
  - `resize(cols: i32, rows: i32)`
  - `size() -> Vector2i`
  - `changed_rows() -> PackedInt32Array`: the rows changed since the last call, which clears them
  - `row_runs(row: i32) -> Array`: runs of equal style, each `{text: String, fg: Color, bg: Color, bold: bool, italic: bool, underline: bool, inverse: bool}`, with default colours as `Color(0, 0, 0, 0)` so the style's own colours apply
  - `cursor() -> Vector2i`
  - `cursor_visible() -> bool`
  - `alternate_screen() -> bool`
  - `application_cursor() -> bool`
  - `bracketed_paste() -> bool`
  - `title() -> String`
  - `scrollback(lines: i32)`, which sets the view offset
- **The logic lives in plain Rust** (`term::Grid`), so `cargo test` covers it without Godot. The Godot class is a thin wrapper.
- **Key encoding stays in GDScript** (Task 6), using `application_cursor()` and `bracketed_paste()`.

- [ ] **Step 1: Write the failing Rust tests,** with VT sequences for:
  - 16-, 256- and true-colour SGR;
  - bold, inverse and reset;
  - cursor moves (CUP, CUU/CUD/CUF/CUB) and a save or restore;
  - erase in line and in display, and `clear`;
  - entering and leaving the alternate screen, with the primary screen restored;
  - wide characters (CJK and emoji) taking two cells;
  - `changed_rows` reporting only touched rows;
  - resizing that keeps content;
  - DECCKM toggling `application_cursor`;
  - the OSC title.
- [ ] **Step 2: Implement it.** Add a Godot test: feed an asciicast's first frames and read the runs back.
- [ ] **Step 3: Run the checks,** including both wasm builds.
- [ ] **Step 4: Commit:** `feat(city): a terminal grid for the station computer`.

---

### Task 4: The station interface and Sample station

**Files:**
- a new `city/godot/core/station/source.gd` (the interface)
- a new `city/godot/core/station/sample_source.gd`
- a new `city/godot/sample_station/`:
  - `README.md`, which says it is synthetic, written for the purpose, and holds no real station's data;
  - `station.json`;
  - `terminal.cast` (asciicast v2);
  - `chat.json`;
  - `files.json` and `files/`;
  - `logs.txt`;
  - `health.json`;
  - `changeset.json` and `diff.patch`;
  - `work.json`
- tests: a new `tests/test_sample_station.gd`

**Interfaces:**
- **`StationSource`** (`RefCounted`) uses the protocol reference's shapes (see "Protocol reference" above), so the apps never branch on the source.
  - **Constants:** `LIVE: bool`, and `label()` returning "Sample" or "Live".
  - **Station list:** `list_stations() -> void`, which emits `stations(list: Array)` with `FleetAgent` dictionaries.
  - **Station calls,** each emitting `result(call_id: int, ok: bool, body, status: int)`:
    - `health(id)`, `files(id, path)` and `file(id, path, max_bytes)` (whose `body` is `{text | bytes, truncated}`);
    - `lifecycle(id, action)`;
    - `changeset_status(id, base)` and `changeset_diff(id, side, path)`.
  - **Streams,** each returning a `StationStream`:
    - `open_logs(id)`, which emits `line(text)`;
    - `open_terminal(id)`, with `send_input(text)`, `send_resize(cols, rows)`, and the signals `data(bytes)` and `exited()`;
    - `open_chat(id, mode, new_session)`, which attaches to the player's newest open session, or creates one when none is open or `new_session` asks for it, and then subscribes. It has `prompt(text)`, `cancel()`, `answer(request_seq, option_id)` and `set_mode(mode)`, and the signals `event(AcpEvent)`, `session(row)` and `replay_done(last_seq)`.

    Every stream has `close()`, and the signals `state_changed(state)` (`connecting | open | offline | closed`) and `failed(reason)`.
  - **Work:**
    - `boards() -> void`
    - `board(board_id)`, followed by a board stream (`snapshot(state)`, `board_event(event)`)
    - `agents()`
    - `card_activities(board_id, card_id)`
    - `move_card(board_id, card_id, to_stage)`
    - `resolve_gate(board_id, gate_id, decision, comment)`
    - `answer(board_id, elicitation_id, option, text)`
  - **Errors** normalise to `{kind: "signed_out" | "no_access" | "offline" | "not_found" | "conflict" | "failed", message}`, following the rules in Task 8.
- **`SampleSource`** plays the recording:
  - **The terminal** replays `terminal.cast` at recorded speed, cut at 3 s a gap. Typed input is echoed, and Enter plays the next recorded command.
  - **The chat** replays `chat.json`: prompts, `agent-update` text chunks and a tool call, and one `permission-request`. Answering it plays the recorded continuation.
  - **Lifecycle** changes the sample's health.
  - **Work:** resolving the sample gate or answering the sample question plays its recorded result.
  - Nothing touches the network or the disk outside `res://sample_station/`.
- **The recording's content:**
  - a coding agent named "Sample agent" on node "sample-node";
  - a short build-and-test run;
  - one board, "Sample board", with one card at `review`, one pending gate and one open question.

  All content is invented and marked Sample.

- [ ] **Step 1: Write the failing tests.**
  - Every call and stream returns the recording's shapes.
  - The terminal replays and responds to Enter.
  - The chat answers its permission request.
  - The gate resolves and the question is answered.
  - `label()` is "Sample".
  - No `HTTPClient`, `WebSocketPeer` or `TCPServer` is created. Check this with a scan of `sample_source.gd` and a runtime assertion hook.
- [ ] **Step 2: Write the recording and the player.**
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `feat(city): Sample station`.

---

### Task 5: The station computer: bezel, desktop, dock, focus and the hand-off

**Files:**
- a new `city/godot/core/station/computer_screen.gd`
- a new `core/station/app.gd` (the app base)
- `core/interaction_controller.gd` (the hand-off)
- `core/input_router.gd` (a computer-focus mode)
- `core/ui/settings.gd` (the `station` section)
- `ui_theme.gd` (a `bezel` key in the `ui` block, defaulting to a plain frame)
- tests: a new `tests/test_computer_screen.gd`

**Interfaces:**
- **The hand-off.**
  - When the core confirms `using {capability: "use"}` at a workstation, the controller fires `use_began`. `main.gd` then settles the camera behind the chair and pushes `ComputerScreen`.
  - Popping the screen sends `StopUsing` through the normal path, so the player stands up.
  - Being moved or released by the core pops the screen.
- **`ComputerScreen.open(desk: Dictionary, source: StationSource, watch := false)`.**
  - **A hot desk** shows the station chooser. With the sample source, this is just "Sample station". With the live source, it is the stations from `list_stations()`.
  - **A bound desk** (`binding {source: "agentpod", ref}`) opens that station. If the source cannot see it, the screen says "You don't have access to this station".
- **The desktop** shows the station's name, purpose, node, a status chip and the time. The **dock** has Terminal, Chat, Files, Logs, Health, Changes and Work.
  - An app whose station capability is missing (`terminal`, `acp`, `fs.read`, `logs`, `health`, `changeset`) is greyed out with the reason. Work needs no station capability.
  - The desktop's footer has "Open in the AgentPod console" and "Open in Superpipeline" when live, through `OS.shell_open` of the configured URLs.
  - When sample, it always offers "Connect your AgentPod":
    - with `station.live` on (desktop builds), it starts signing in;
    - with it off, it explains that live mode connects to the player's own AgentPod and is off, and opens Settings at "Station computer";
    - on web and mobile, it says sign-in needs the desktop app for now.
- **The bezel** comes from the style's `ui.bezel` block: `{shape: "crt" | "glass" | "plain" | ..., colour, radius, margin}`. It shows:
  - the style's frame;
  - the "Sample" or "Live" badge;
  - the station's name;
  - a "Stand up" button.
- **Focus rules.**
  - While the screen is up, the input router is in computer mode, and no game action fires.
  - F10, "Stand up", and B held for 0.5 s leave.
  - Esc leaves unless a terminal or text field has focus; there it goes to the field.
- **Controller and touch.**
  - The dock and every button are focusable with the d-pad.
  - With a controller only, the terminal and chat show "Typing needs a keyboard" on desktop.
  - On touch, focusing a text field calls `DisplayServer.virtual_keyboard_show`.
- **Watch mode** (`watch = true`) is for "Look at screen" from the stand anchor. Input is off, and the bezel says "Watching".
  - **Sample:** allowed at desks where an agent sits. It opens Sample station read-only.
  - **Live:** allowed where the desk is bound and the live source can see the station.
- **Settings** gain a `station` section:
  - `live: false`;
  - `hub_url: ""`;
  - `superpipeline_url: ""`;
  - `console_url: ""`;
  - `client_id: "agentnagar"`;
  - `first_shell_notice_shown: false`.

  They appear in the Settings screen under "Station computer", with the live toggle labelled "Live mode (connects to your AgentPod)".

- [ ] **Step 1: Write the failing tests.**
  - The hand-off pushes the screen, and popping stands the player up.
  - Being moved pops the screen.
  - Review Focus 3: W, A, S, D, E, Space, Tab, M and Esc with the terminal focused never reach the game, and F10 or a 0.5 s B hold always leave.
  - Missing capabilities grey out their apps.
  - A bound desk without access says so.
  - Watch mode has input off.
  - The live toggle is off by default, and with it off no network class is created.
  - The bezel reads the style's block, and a style without one gets the plain frame.
- [ ] **Step 2: Implement it.** Use placeholder app bodies that say the app's name; Tasks 6 and 7 fill them.
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `feat(city): the station computer`.

---

### Task 6: The apps: Terminal, Logs, Files, Health, Changes

**Files:**
- new files under `city/godot/core/station/apps/`: `terminal_app.gd`, `logs_app.gd`, `files_app.gd`, `health_app.gd`, `changes_app.gd`
- tests: a new `tests/test_station_apps.gd` (against `SampleSource` and a scripted stub source)

**Interfaces:**
- **Terminal.**
  - It draws `TermGrid` rows with the style's monospace face (the `ui` block's `font_mono`, falling back to the engine's monospace). It redraws only `changed_rows()`, draws the cursor and supports scrollback by wheel.
  - Its size fits the app area at 80×24 or more. It sends a resize on open and on every size change; the hub opens at 80×24 and expects the resize at once.
  - **Key encoding:** printable characters, Enter `\r`, Backspace `\x7f`, Tab and Shift-Tab, Esc, the arrows (`\x1b[A` or, in application cursor mode, `\x1bOA`), Home and End, PgUp and PgDn, Delete, F1–F12, Ctrl-letter, and Alt as an Esc prefix.
  - **Paste:** Ctrl-Shift-V or the middle button pastes, wrapped in bracketed paste when the grid asks for it.
  - **Exit:** `exited` shows "Session ended · Reconnect".
  - **First open:** the first terminal opened while live shows a one-line notice that it is a real shell on the station, and records `first_shell_notice_shown`.
- **Logs:** a live tail with a 5,000-line ring, Pause/Resume, and search that highlights matches and jumps between them.
- **Files:** a tree from `files()`, expanded lazily. A text file previews up to 1 MiB, with a "Truncated" note when `truncated`. A binary file shows its size and "Binary file". It is read-only.
- **Health:** running, cpu, memory, disk and uptime, refreshed every 5 s while visible, plus the node's online or offline state from the station list.
  - Start, Stop and Restart each ask for confirmation naming the station; Stop and Restart say they are real when live.
  - The result updates the view with the returned health.
- **Changes:** the branch, head and base, and the file list for both sides with insertions and deletions. It shows a diff for the selected file with added and removed lines coloured from the style's palette. It is read-only.
- **Errors, in every app:**
  - `offline` shows "Station offline" with Retry;
  - `no_access` shows "You don't have access to this station";
  - `signed_out` shows "Sign in again" (Task 8 wires it);
  - `failed` shows a one-line message without the body.

- [ ] **Step 1: Write the failing tests,** for each app against the sample: rendering, input sent, confirmations, and each error kind through a stub source. For the terminal, test the key encoding table in both cursor modes, bracketed paste, and resize on size change.
- [ ] **Step 2: Implement it.**
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `feat(city): terminal, logs, files, health and changes`.

---

### Task 7: The apps: Chat and Work

**Files:**
- new files `core/station/apps/chat_app.gd` and `work_app.gd`
- tests: `tests/test_station_apps.gd`

**Interfaces:**
- **Chat** renders the session's `AcpEvent`s in `seq` order and removes duplicates by `seq`:
  - `user-prompt` as the player's bubble;
  - `agent-update` from the ACP `sessionUpdate` payload:
    - `agent_message_chunk` and `agent_thought_chunk` text is appended;
    - `tool_call` and `tool_call_update` become a collapsible row with the title, kind and status;
    - `plan` becomes a checklist;
    - an unknown `sessionUpdate` becomes a quiet "(update)" row, never an error;
  - `permission-request` as a card with its options. Choosing one sends `answer(requestSeq, optionId)`, and requests marked `auto` show as already answered;
  - `state` as the status chip (`starting`, `idle`, `working`, `waiting`, `ended`);
  - `error` as a notice built from its `kind`.

  It can:
  - send a prompt;
  - cancel while working;
  - switch the mode among `ask`, `accept-edits` and `full-auto`, where `full-auto` asks for confirmation;
  - open a new session, after the old one has ended or when chosen from the menu.

  The session's status also drives the monitor's activity pulse (Task 11).
- **Work.**
  - **Which agent is this station's.** No route maps an AgentPod station to a Superpipeline agent; see the amendment. The first time Work opens for a station, it asks "Which Superpipeline agent works at this station?", listing `agents()` with "None". The choice is stored per station ID in `user://station_links.cfg`, which holds IDs only. Sample's link is built in.
  - **Its cards.** Each board from `boards()` is opened as a snapshot plus its push-only stream. The app shows the cards whose `delegateAgentId` is the linked agent, grouped by board and stage, each with a state chip.
  - **Pending gates** on those cards: Approve, Request changes and Reject, each with a comment field. Reject and Request changes ask for confirmation naming the board.
  - **Open questions:** no options means a free-text answer; options become choices; an `interactive` option also takes text.
  - **A card's activity** comes from `card_activities`, shown when the card is selected.
  - **Moving a card** to another stage from its menu. A refusal (`WIP_LIMIT`, 409) shows its message.
  - **Stream events** update the view without a refetch. Reconnecting refetches the snapshot.

- [ ] **Step 1: Write the failing tests,** against the sample and a stub source:
  - every event type renders, and an unknown `sessionUpdate` is tolerated;
  - duplicate `seq` values are ignored;
  - the permission answer is sent;
  - `full-auto` asks for confirmation;
  - the link prompt is stored and remembered;
  - cards are filtered by the linked agent;
  - the gate decisions send the right body;
  - the answer body is correct for each question shape;
  - a 409 on a move shows its message.
- [ ] **Step 2: Implement it.**
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `feat(city): chat and work on the station computer`.

---

### Task 8: Live mode, part 1: the fake hub, signing in, and REST

**Files:**
- a new `city/godot/tests/fake_hub/fake_hub.gd` (a `TCPServer` HTTP/1.1 and WebSocket server, run inside the test process), with `fake_hub/recordings/*.json`
- new files `core/station/credential.gd`, `core/station/http.gd` (a small `HTTPClient` wrapper that supports streaming for SSE), and `core/station/live_source.gd`, whose REST parts are this task's
- tests: a new `tests/test_live_rest.gd` and `tests/test_credential.gd`

**Interfaces:**
- **The fake hub** serves the AgentPod routes and the Superpipeline routes on two ports, with the shapes in the protocol reference's §1–§3 and §6–§7.
  - It checks `Authorization: Bearer`; `?token=` is accepted only on WebSocket upgrades.
  - It answers **404 to any route it does not know, and fails the test on a message type it does not know**, so the client cannot drift from the recordings.
  - It can be told to:
    - expire tokens after N seconds;
    - take a station offline;
    - refuse with 401 or 403.
- **Signing in** (`credential.gd`) follows the flow `apn fleet login` uses: authorization code with PKCE through a loopback listener, then a device credential. The amendment explains why.
  1. Bind a `TCPServer` on `127.0.0.1:0` and build `redirect_uri = http://127.0.0.1:<port>/callback`.
  2. Make a PKCE verifier of 48 random bytes in base64url, with an S256 challenge, and a random `state`, using `Crypto.generate_random_bytes`.
  3. Open the browser at `{hub}/api/auth/authorize?client=<client_id>&redirect_uri=…&response_type=code&state=…&code_challenge=…&code_challenge_method=S256`.
  4. On the callback:
     - check `state` and answer the browser with a plain "You can return to Agentnagar" page;
     - `POST {hub}/api/auth/token/exchange` with `{code, code_verifier, redirect_uri}` and **no Origin header**;
     - `POST {hub}/api/auth/devices` with `{name: "Agentnagar on <hostname>"}`, using that token.
  5. Store `{hub, device_id, secret}` in `user://station_credential.json`, readable by the owner only (`chmod 600` on Linux and macOS, through `OS.execute` of `chmod` after writing, or `FileAccess.set_unix_permissions`).
  6. Tokens: `POST {hub}/api/auth/devices/token?client=<client_id>` with `Authorization: Bearer <id>:<secret>` gives `{token, expiresIn}`. Keep the token in memory, and re-exchange when **30 s** are left or after any 401. A second 401 in a row means the credential is refused: signed out.
  7. Disconnecting sends `DELETE {hub}/api/auth/devices/<id>` with a fresh token, then deletes the file whether or not the call succeeded.

  A 5-minute timeout applies to the whole sign-in. Cancelling closes the listener.
- **The live source's REST calls** implement `StationSource` over the recorded routes:
  - `GET /api/fleet/agents`;
  - health, files and file (a raw body, with `X-Truncated`);
  - logs as SSE (`data:` lines);
  - lifecycle and the changeset calls.

  **Superpipeline** uses the same token, with `Authorization: Bearer` only:
  - `GET /v1/boards` and `/v1/boards/:id`;
  - `/v1/agents`;
  - card activities;
  - move, resolve and answer.
- **Error mapping:**
  - 401 re-exchanges once, then gives `signed_out`;
  - 403 gives `no_access`;
  - 404 gives `not_found`;
  - 409 gives `offline` from the station write, lifecycle and changeset routes, and `conflict` from Superpipeline;
  - 502 from health, files, file and logs gives `offline` when the body's error names the node as offline or disconnected, and `failed` otherwise;
  - network failure gives `offline`.

  Superpipeline's three error shapes are all read for their message.
- **The redaction rule.** No response body, token, secret or URL query string is ever passed to `print`, `push_warning` or `push_error`. The only messages allowed are fixed strings plus a route template and a status.

- [ ] **Step 1: Write the failing tests** against the fake hub:
  - the whole sign-in, with a scripted "browser" that follows the authorize redirect;
  - a `state` mismatch is refused;
  - the credential file is owner-only;
  - token refresh before expiry, on a 2-second lifetime, is Review Focus 1;
  - two 401s in a row sign the player out;
  - Disconnect revokes and deletes;
  - every REST call's request and parsed result;
  - every error mapping, including 502-offline against 409-offline;
  - SSE lines arrive in order;
  - the redaction rule: capture the log and the error watch during a failing session, and assert that no body appears.
- [ ] **Step 2: Implement it.**
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `feat(city): signing in and the live station's REST routes`.

---

### Task 9: Live mode, part 2: the terminal, chat and board streams

**Files:**
- `core/station/live_source.gd` (the streams)
- `tests/fake_hub/fake_hub.gd` (the WebSocket frames)
- tests: a new `tests/test_live_streams.gd`

**Interfaces:**
- **Terminal:** `WS {hub}/api/stations/:id/terminal?token=<token>`, with no Origin header.
  - It sends `{t:"input", data}` and `{t:"resize", cols, rows}`, with the resize immediately after opening.
  - It receives `{t:"data", data: base64}`, which is decoded and fed to `TermGrid`, and `{t:"exit"}`.
  - Close 1008 gives `no_access` or `signed_out`; the client re-exchanges once and retries. Close 1011 gives `offline`.
  - The shell survives a disconnect, so reconnecting resumes it.
- **Chat:**
  - `GET /api/stations/:id/acp/sessions` first, attaching to the newest session not `ended`; `POST /api/stations/:id/acp/sessions` with `{mode}` only when none is open, or for "New session". A current hub keeps several sessions a station, each its own agent process, and answers every POST with a new one (201). A 409 "already exists" comes only from an older node that keeps one session a station, and is a fallback: list again and attach to the newest one not `ended`. (Corrected in the final fix wave; this step first read "a 409 means reuse", which made every open start a new agent process.)
  - Then `WS /api/acp/sessions/:sessionId/ws?token=…`, and send `{t:"subscribe", sinceSeq}`.
  - It handles `session`, `event`, `replay-done` and `bye`.
  - It sends `prompt`, `cancel`, `permission-answer {requestSeq, optionId}` and `set-mode`.
  - Reconnecting subscribes from the last `seq` seen, and an event carrying `seq: 0` never moves the cursor.
- **Board:** `WS {superpipeline}/v1/boards/:id/ws`, authorised with `Authorization: Bearer` in `handshake_headers`. It is push-only: `{kind:"snapshot"}` first, then `{kind:"event"}`. The client never sends on it.
- **Reconnecting:** exponential backoff of 1, 2, 4, 8 and 16 s, then every 30 s, while the app is open. The token is refreshed before each attempt. The state shows "Reconnecting…".
- **The drift guard:** the fake hub fails the test on any client frame type the recordings do not contain.

- [ ] **Step 1: Write the failing tests** against the fake hub:
  - terminal round trip, resize at once, exit, and reconnect resuming the session;
  - chat listed first and attached to, created only when none is open or for "New session", the older node's 409 still attached to, replay and then live events, no duplicates across a reconnect (Review Focus 2), and permission answer and mode frames;
  - the board snapshot, then events;
  - the node going offline and coming back (Review Focus 2);
  - a token expiring mid-stream (Review Focus 1);
  - an unknown frame type failing the fake hub.
- [ ] **Step 2: Implement it.**
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `feat(city): live terminal, chat and board streams`.

---

### Task 10: Privacy: the planted-marker test and what others see

**Files:**
- a new `tests/test_station_privacy.gd`
- `main.gd` and the interaction controller (the watch-mode gate), and whatever the test finds

**Interfaces:**
- **A scripted live session against the fake hub** plants a unique marker in the station name's purpose, the terminal output, a chat reply, a file name and its content, a log line, a diff, a card title, a gate comment and a question. It then:
  - opens every app;
  - types into the terminal and chat;
  - answers the permission request, the gate and the question;
  - forces a 401, a 502 and a malformed frame.
- **The test records every channel:**
  - every `CityWorld` call and its arguments, through a recording bridge;
  - the core's input log, projections and a replay of the session;
  - the client log file;
  - the error watch;
  - `print` output, by capturing `user://logs`;
  - anything the network layer would send to a city server. Today nothing does; the test asserts that the station code never names the city server's address.

  It fails if the marker appears in any of them.
- **Others' projections** carry `using {target, capability: "use", anchor}` and nothing else about the station.
- **"Look at screen"** is offered only as Review Focus 5 says. Watch mode never sends input.

- [ ] **Step 1: Write the test.** It should fail first on at least one planted channel; if none fails, prove the test can catch a leak by adding one on purpose in a throwaway run. Record the proof in the report.
- [ ] **Step 2: Fix what it finds.**
- [ ] **Step 3: Run the checks.**
- [ ] **Step 4: Commit:** `test(city): station content stays on the station computer`.

---

### Task 11: The workstation in every style

**Files:**
- the style packs:
  - `styles/pack_3d.gd` and the five 3D styles' kit builders and assets;
  - `styles/pixel_art/pack.gd` and its sprites;
  - each `style.json`'s `ui.bezel`
- `core/station/monitor.gd` (the in-world monitor)
- tests: the pack tests, the collision audit, and a new `tests/test_monitor.gd`

**Interfaces:**
- **The desk, chair and monitor** in all six styles fit the footprint, and the audit stays at 0. The `display` anchor sits at the monitor's face.
- **The monitor states:**
  - "idle": the style's dark screen;
  - "in use": the style's screen glow;
  - for the player's own desk while seated, or while watching within 4 m: a `SubViewport` of the computer screen at a low resolution (256×160 in 3D, the sprite's screen size in pixel art), updated at **10 Hz**, and at no other time;
  - a coarse activity pulse while the chat session's status is `working`, for the player's own view and watch mode only.

  Every other viewer sees only idle or in use, and in use means the seat is occupied.
- **The bezels:**
  - a CRT for pixel art;
  - glass for neon noir;
  - a wooden frame for solarpunk;
  - a chunky frame for voxel;
  - a clean flat frame for low-poly;
  - an inked frame for anime.
- **Pixel art** draws the desk and monitor as sprites. The station computer uses the pixel font at whole-number scales, falling back to the overlay face for small text.

- [ ] **Step 1: Write the failing tests.**
  - The monitor updates at 10 Hz for the player's own desk only.
  - Other desks show idle or in use.
  - The pulse appears only in the owner's and the watcher's views.
  - The audit is at 0 in six styles.
  - Each style has a bezel.
- [ ] **Step 2: Build the art,** run the kit tests and regenerate the kits.
- [ ] **Step 3: Run the checks.** Include a frame-bench spot check of the workshop with eight desks in use, which must stay within the Part A bench numbers ±5%.
- [ ] **Step 4: Commit:** `feat(city): workstations drawn in every style`.

---

### Task 12: Evidence, docs and amendments

**Files:**
- a new `city/godot/evidence/workstation-notes.md`, with screenshots of each app in sample mode in two styles, the bezel in all six, the monitor states, and "Look at screen"
- `city/README.md` (a "Station computer" section covering sample and live mode, the settings, what leaves the machine and what does not, and the hub configuration live mode needs)
- the spec's §10 (a "decided during the build (Part B)" subsection, from the ledger's rulings)

- [ ] **Step 1: Capture the evidence,** and view every image.
- [ ] **Step 2: Write the notes, the README section and the amendments.**
- [ ] **Step 3: Run all the checks,** and record the counts.
- [ ] **Step 4: Commit:** `docs(city): workstation evidence and notes`.

**Manual, and needing the operator's authorization:** one live session against the operator's own development hub and board, recorded in the evidence notes. It needs:
- the `agentnagar` client registered on that hub;
- the internal SJL decision (spec §5.6) accepted.

It is not part of this plan's automated completion, and the release notes must say whether it was done.
