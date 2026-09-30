//! A Godot extension exposing the city world as the `CityWorld` class, and
//! the station computer's terminal grid as `TermGrid`.

pub mod bridge;
pub mod term;

use godot::prelude::*;

struct CityExtension;

#[gdextension]
unsafe impl ExtensionLibrary for CityExtension {}

/// The city world, stepped and projected from GDScript. It only ever hands
/// out projections, so no style pack can show what its viewer may not see.
#[derive(GodotClass)]
#[class(init, base = RefCounted)]
pub struct CityWorld {
    session: bridge::Session,
    /// The folder the manifest was read from (a `res://` path in a
    /// package), where sample panels are read (see `panel_json`).
    fixture_dir: GString,
}

#[godot_api]
impl CityWorld {
    /// Loads a world; returns JSON `{"ok": bool, ...}`.
    #[func]
    fn load(
        &mut self,
        manifest_json: GString,
        feed_jsonl: GString,
        seed: i64,
        crowd: i64,
    ) -> GString {
        let seed = u64::try_from(seed).unwrap_or(0);
        let crowd = u32::try_from(crowd).unwrap_or(0);
        GString::from(
            self.session
                .load(
                    &manifest_json.to_string(),
                    &feed_jsonl.to_string(),
                    seed,
                    crowd,
                )
                .as_str(),
        )
    }

    #[func]
    fn step(&mut self) -> i64 {
        self.session.step()
    }

    #[func]
    fn tick(&self) -> i64 {
        self.session.tick()
    }

    #[func]
    fn set_operator(&mut self, on: bool) {
        self.session.set_operator(on);
    }

    #[func]
    fn project_json(&self, viewer: GString) -> GString {
        GString::from(self.session.project_json(&viewer.to_string()).as_str())
    }

    /// The places, without people, and the walkable grid the core derived
    /// from them (`grid`), which `NavQuery` loads.
    #[func]
    fn layout_json(&self) -> GString {
        GString::from(self.session.layout_json().as_str())
    }

    /// Where the loaded manifest was read from, so sample panels are read
    /// beside it (its `panels/` folder).
    #[func]
    fn set_fixture_dir(&mut self, dir: GString) {
        self.fixture_dir = dir;
    }

    /// The panel placement `target` shows, as JSON, or an error JSON (see
    /// `Session::panel_json_in`): only `sample` bindings, read from the
    /// fixture folder with Godot's file access, so a package's `res://`
    /// fixtures are read as a checkout's are; `not-configured` before a
    /// folder is set.
    #[func]
    fn panel_json(&self, target: GString) -> GString {
        let read = |path: &str| {
            let path = GString::from(path);
            godot::classes::FileAccess::file_exists(&path)
                .then(|| godot::classes::FileAccess::get_file_as_string(&path).to_string())
        };
        let dir = self.fixture_dir.to_string();
        GString::from(
            self.session
                .panel_json_in(&target.to_string(), &dir, &read)
                .as_str(),
        )
    }

    /// The built-in catalogue of kinds, as JSON.
    #[func]
    fn catalogue_json(&self) -> GString {
        GString::from(self.session.catalogue_json().as_str())
    }

    /// The core's own answers for every grid cell, row by row, for checking
    /// the client's copy of the grid (see `Session::grid_answers`).
    #[func]
    fn grid_answers(&self) -> PackedInt32Array {
        PackedInt32Array::from(self.session.grid_answers().as_slice())
    }

    /// Joins as the local player: `as_` is `registered` or `observer`,
    /// `look` is `"OUTFIT,HAIR"`. Returns `{"ok": true, "id": ...}`.
    #[func]
    fn join(&mut self, as_: GString, look: GString) -> GString {
        GString::from(
            self.session
                .join(&as_.to_string(), &look.to_string())
                .as_str(),
        )
    }

    /// Submits `Go`, `Steer`, `Depart`, `Board` or `Alight` for the
    /// player's own occupant.
    #[func]
    fn command(&mut self, json: GString) -> GString {
        GString::from(self.session.command(&json.to_string()).as_str())
    }

    /// Boards the vehicle at the player's platform, or waits for the next.
    #[func]
    fn board(&mut self) -> GString {
        GString::from(self.session.board().as_str())
    }

    /// Steps the player off the vehicle standing with its doors open.
    #[func]
    fn alight(&mut self) -> GString {
        GString::from(self.session.alight().as_str())
    }

    /// The player's own events since they were last taken, as a JSON array
    /// (its refusals, boarding and stepping off, being left behind).
    #[func]
    fn take_player_events(&mut self) -> GString {
        GString::from(self.session.take_player_events_json().as_str())
    }

    #[func]
    fn leave(&mut self) -> GString {
        GString::from(self.session.leave().as_str())
    }

    #[func]
    fn input_log_jsonl(&self) -> GString {
        GString::from(self.session.input_log_jsonl().as_str())
    }

    /// `public`, or the player's own ID once it joins.
    #[func]
    fn viewer(&self) -> GString {
        GString::from(self.session.viewer().as_str())
    }

    /// Holds every following step to the core's invariants.
    #[func]
    fn set_checking(&mut self, on: bool) {
        self.session.set_checking(on);
    }

    /// Invariant violations found while checking, as a JSON array.
    #[func]
    fn violations_json(&self) -> GString {
        GString::from(self.session.violations_json().as_str())
    }

    /// Replays the session from its sources and input log to this tick:
    /// `{"tick": n, "identical": bool}`.
    #[func]
    fn replay_json(&self) -> GString {
        GString::from(self.session.replay_json().as_str())
    }
}

/// A terminal grid for the station computer's Terminal app, wrapping a
/// `vt100`-driven `term::Grid`. Only Godot-facing plumbing lives here; the
/// parsing and diffing logic is `term::Grid`, tested without Godot.
#[derive(GodotClass)]
#[class(init, base = RefCounted)]
pub struct TermGrid {
    grid: Option<term::Grid>,
}

#[godot_api]
impl TermGrid {
    /// Starts a fresh terminal of the given size, discarding any prior
    /// content. `term::Grid` clamps out-of-range sizes: `cols` to at least
    /// one, `rows` to at least two (a single row can crash `vt100` on
    /// wrapping text), neither above `u16::MAX`.
    #[func]
    fn setup(&mut self, cols: i32, rows: i32) {
        self.grid = Some(term::Grid::new(cols, rows));
    }

    /// Feeds PTY output to the terminal. A no-op before `setup`.
    #[func]
    fn feed(&mut self, bytes: PackedByteArray) {
        if let Some(grid) = &mut self.grid {
            grid.feed(bytes.as_slice());
        }
    }

    /// Resizes the terminal in place, keeping its content. Sizes are
    /// clamped the same way as `setup`.
    #[func]
    fn resize(&mut self, cols: i32, rows: i32) {
        if let Some(grid) = &mut self.grid {
            grid.resize(cols, rows);
        }
    }

    /// The terminal's size, as `Vector2i(cols, rows)`.
    #[func]
    fn size(&self) -> Vector2i {
        let Some(grid) = &self.grid else {
            return Vector2i::ZERO;
        };
        let (cols, rows) = grid.size();
        Vector2i::new(i32::from(cols), i32::from(rows))
    }

    /// The rows changed since the last call, which this clears.
    #[func]
    fn changed_rows(&mut self) -> PackedInt32Array {
        let Some(grid) = &mut self.grid else {
            return PackedInt32Array::new();
        };
        let rows: Vec<i32> = grid
            .take_changed_rows()
            .into_iter()
            .map(i32::from)
            .collect();
        PackedInt32Array::from(rows.as_slice())
    }

    /// Runs of equal style across `row`, each a `Dictionary` with `text`,
    /// `col` (its first cell's column), `cells` (how many columns it covers,
    /// by `vt100`'s widths), `fg`, `bg`, `bold`, `italic`, `underline` and
    /// `inverse`. Default colours come through as `Color(0, 0, 0, 0)`, so
    /// the style's own colours apply. Empty for a negative `row`, or one at
    /// or beyond the grid's own row count.
    #[func]
    fn row_runs(&self, row: i32) -> VarArray {
        let mut out = VarArray::new();
        let Some(grid) = &self.grid else {
            return out;
        };
        let Ok(row) = u16::try_from(row) else {
            return out; // negative, or past what a row index can even be
        };
        if row >= grid.size().1 {
            return out;
        }
        for run in grid.row_runs(row) {
            let (fr, fg, fb, fa) = term::to_godot_rgba(run.fg);
            let (br, bg, bb, ba) = term::to_godot_rgba(run.bg);
            let mut d = VarDictionary::new();
            d.set(
                &Variant::from(GString::from("text")),
                &Variant::from(GString::from(&run.text)),
            );
            d.set(
                &Variant::from(GString::from("col")),
                &Variant::from(i32::from(run.col)),
            );
            d.set(
                &Variant::from(GString::from("cells")),
                &Variant::from(i32::from(run.cells)),
            );
            d.set(
                &Variant::from(GString::from("fg")),
                &Variant::from(Color::from_rgba8(fr, fg, fb, fa)),
            );
            d.set(
                &Variant::from(GString::from("bg")),
                &Variant::from(Color::from_rgba8(br, bg, bb, ba)),
            );
            d.set(
                &Variant::from(GString::from("bold")),
                &Variant::from(run.bold),
            );
            d.set(
                &Variant::from(GString::from("italic")),
                &Variant::from(run.italic),
            );
            d.set(
                &Variant::from(GString::from("underline")),
                &Variant::from(run.underline),
            );
            d.set(
                &Variant::from(GString::from("inverse")),
                &Variant::from(run.inverse),
            );
            out.push(&Variant::from(d));
        }
        out
    }

    /// The cursor's position, as `Vector2i(col, row)`.
    #[func]
    fn cursor(&self) -> Vector2i {
        let Some(grid) = &self.grid else {
            return Vector2i::ZERO;
        };
        let (col, row) = grid.cursor();
        Vector2i::new(i32::from(col), i32::from(row))
    }

    /// Whether the cursor should be drawn at all (DECTCEM).
    #[func]
    fn cursor_visible(&self) -> bool {
        self.grid.as_ref().is_some_and(term::Grid::cursor_visible)
    }

    /// Whether the alternate screen buffer is active.
    #[func]
    fn alternate_screen(&self) -> bool {
        self.grid.as_ref().is_some_and(term::Grid::alternate_screen)
    }

    /// Whether the arrow keys should be encoded as application (`SS3`)
    /// sequences rather than the normal (`CSI`) ones (DECCKM). Key encoding
    /// itself stays in GDScript.
    #[func]
    fn application_cursor(&self) -> bool {
        self.grid
            .as_ref()
            .is_some_and(term::Grid::application_cursor)
    }

    /// Whether pasted text should be wrapped in bracketed-paste markers.
    #[func]
    fn bracketed_paste(&self) -> bool {
        self.grid.as_ref().is_some_and(term::Grid::bracketed_paste)
    }

    /// The terminal's window title, set by an OSC sequence.
    #[func]
    fn title(&self) -> GString {
        match &self.grid {
            Some(grid) => GString::from(grid.title()),
            None => GString::new(),
        }
    }

    /// Sets the scrollback view offset: `0` shows the live screen. Negative
    /// offsets are clamped to zero.
    #[func]
    fn scrollback(&mut self, lines: i32) {
        if let Some(grid) = &mut self.grid {
            grid.set_scrollback(lines.max(0) as usize);
        }
    }

    /// How far back the view is, in lines, `0` being the live screen: the
    /// last `scrollback` request as clamped to the history, and moved on as
    /// new output scrolls more lines into it.
    #[func]
    fn scrollback_offset(&self) -> i32 {
        self.grid.as_ref().map_or(0, |grid| {
            i32::try_from(grid.scrollback()).unwrap_or(i32::MAX)
        })
    }
}
