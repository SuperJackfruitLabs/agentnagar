//! `Grid`, a terminal screen driven by the `vt100` crate: it parses PTY
//! bytes and hands back the rendered rows, cursor and terminal modes the
//! station computer's Terminal app draws. Plain Rust, tested without Godot;
//! `TermGrid` in `lib.rs` is a thin wrapper around it.

use std::collections::BTreeSet;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use vt100::Color;

/// Scrollback kept beyond the visible screen, in lines. Not part of the
/// public interface; callers move the view into it with `set_scrollback`.
const SCROLLBACK_LINES: usize = 2000;

/// One run of cells sharing the same style, the unit `row_runs` hands back.
/// `col` is the column its first cell is in and `cells` how many columns it
/// covers, both from `vt100`'s own cell widths: a wide character (an emoji,
/// a CJK ideograph) covers two, and a combining mark shares its base's
/// cell. A cell holding anything but one printable ASCII character is a
/// run of its own, so every other run is one character a cell. A caller
/// draws from these, never by measuring text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Run {
    pub text: String,
    pub col: u16,
    pub cells: u16,
    pub fg: Color,
    pub bg: Color,
    pub bold: bool,
    pub italic: bool,
    pub underline: bool,
    pub inverse: bool,
}

/// Captures the window title `vt100` reports via a callback rather than
/// storing itself, as of 0.16.2 (an OSC 0/2 sequence).
#[derive(Debug, Default, Clone, PartialEq, Eq)]
struct TermCallbacks {
    title: String,
}

impl vt100::Callbacks for TermCallbacks {
    fn set_window_title(&mut self, _screen: &mut vt100::Screen, title: &[u8]) {
        self.title = String::from_utf8_lossy(title).into_owned();
    }
}

/// A terminal screen: feeds bytes to a `vt100::Parser` and tracks which rows
/// changed since they were last read, so the caller redraws only those.
pub struct Grid {
    parser: vt100::Parser<TermCallbacks>,
    cols: u16,
    rows: u16,
    /// Rows changed since the last `take_changed_rows`, cleared on read.
    dirty: BTreeSet<u16>,
    /// A hash of each row's contents and style, to detect what changed.
    row_hashes: Vec<u64>,
    /// The scrollback view offset last set by `set_scrollback`: `0` is the
    /// live screen; anything else is history, where `cursor_visible`
    /// hides the live cursor the way a real terminal does.
    scrollback_offset: usize,
}

impl Grid {
    /// Starts a fresh terminal of the given size (columns, then rows), with
    /// no content carried over from any prior session. Every row starts
    /// marked changed, so the first draw paints the whole (blank) screen.
    /// `cols` is clamped to `1..=u16::MAX` and `rows` to `MIN_ROWS..=u16::MAX`
    /// (see its doc comment): `vt100` panics on the next `process()` if
    /// given an empty grid, or a single-row one fed text that wraps, and
    /// neither dimension can exceed `u16::MAX`.
    pub fn new(cols: i32, rows: i32) -> Self {
        let cols = clamp_dimension(cols, 1);
        let rows = clamp_dimension(rows, MIN_ROWS);
        let parser = vt100::Parser::new_with_callbacks(
            rows,
            cols,
            SCROLLBACK_LINES,
            TermCallbacks::default(),
        );
        let mut grid = Self {
            parser,
            cols,
            rows,
            dirty: BTreeSet::new(),
            row_hashes: vec![0; rows as usize],
            scrollback_offset: 0,
        };
        grid.rehash_all();
        grid
    }

    /// Feeds PTY output through the parser and records which rows changed.
    pub fn feed(&mut self, bytes: &[u8]) {
        self.parser.process(bytes);
        self.rehash_changed();
    }

    /// Resizes the terminal in place, keeping its content. Every row is
    /// marked changed, since a resize can reflow the whole screen. `cols`
    /// and `rows` are clamped the same way as `new`.
    pub fn resize(&mut self, cols: i32, rows: i32) {
        let cols = clamp_dimension(cols, 1);
        let rows = clamp_dimension(rows, MIN_ROWS);
        self.parser.screen_mut().set_size(rows, cols);
        self.cols = cols;
        self.rows = rows;
        self.row_hashes = vec![0; rows as usize];
        // Drop any pending row beyond the new row count: `row_hashes` above
        // is already sized to it, but `dirty` is a separate set that a
        // shrink would otherwise leave holding stale, now out-of-range
        // rows forever (they can never again be less than `self.rows` in
        // `take_changed_rows`' caller, but nothing would remove them).
        // `rehash_all` below marks every row in the new size changed
        // anyway, so clearing first is equivalent to (and simpler than)
        // retaining only rows `< rows`.
        self.dirty.clear();
        self.rehash_all();
    }

    /// The terminal's size, as (columns, rows).
    pub fn size(&self) -> (u16, u16) {
        (self.cols, self.rows)
    }

    /// The rows changed since the last call, which this clears.
    pub fn take_changed_rows(&mut self) -> Vec<u16> {
        std::mem::take(&mut self.dirty).into_iter().collect()
    }

    /// Runs of equal style across `row`, left to right. An empty cell
    /// contributes a space, so a run of blanks still carries its
    /// background. The cell after a wide character is skipped, since its
    /// content is already covered by the wide character's own run.
    pub fn row_runs(&self, row: u16) -> Vec<Run> {
        let screen = self.parser.screen();
        let mut runs: Vec<Run> = Vec::new();
        let mut skip_next = false;
        let mut last_plain = false;
        for col in 0..self.cols {
            if skip_next {
                skip_next = false;
                continue;
            }
            let (text, fg, bg, bold, italic, underline, inverse, wide) = match screen.cell(row, col)
            {
                Some(cell) => {
                    // `Cell::contents` returns `&str` as of 0.16.2 (owned
                    // `String` before); `.to_string()` matches the empty
                    // branch's type either way.
                    let text = if cell.has_contents() {
                        cell.contents().to_string()
                    } else {
                        " ".to_string()
                    };
                    (
                        text,
                        cell.fgcolor(),
                        cell.bgcolor(),
                        cell.bold(),
                        cell.italic(),
                        cell.underline(),
                        cell.inverse(),
                        cell.is_wide(),
                    )
                }
                None => (
                    " ".to_string(),
                    Color::Default,
                    Color::Default,
                    false,
                    false,
                    false,
                    false,
                    false,
                ),
            };
            skip_next = wide;
            let width = if wide { 2 } else { 1 };
            // A cell holding anything but one printable ASCII character (a
            // wide character, a combining sequence, any other script) is a
            // run of its own, so the caller draws it at its own column
            // instead of trusting a font's advances to land there.
            let plain = !wide && text.len() == 1 && text.is_ascii();

            let same_style = plain
                && last_plain
                && runs.last().is_some_and(|r: &Run| {
                    r.fg == fg
                        && r.bg == bg
                        && r.bold == bold
                        && r.italic == italic
                        && r.underline == underline
                        && r.inverse == inverse
                });
            if same_style {
                // `same_style` only holds when `runs` is non-empty.
                let run = runs.last_mut().expect("same_style implies a last run");
                run.text.push_str(&text);
                run.cells += width;
                last_plain = plain;
            } else {
                runs.push(Run {
                    text,
                    col,
                    cells: width,
                    fg,
                    bg,
                    bold,
                    italic,
                    underline,
                    inverse,
                });
                last_plain = plain;
            }
        }
        runs
    }

    /// The cursor's position, as (column, row).
    pub fn cursor(&self) -> (u16, u16) {
        let (row, col) = self.parser.screen().cursor_position();
        (col, row)
    }

    /// Whether the cursor should be drawn at all: hidden by DECTCEM, or
    /// while scrolled back into history, the way a real terminal hides its
    /// live cursor while showing an older part of the screen. `cursor()`
    /// itself still reports the live position even while scrolled back.
    pub fn cursor_visible(&self) -> bool {
        self.scrollback_offset == 0 && !self.parser.screen().hide_cursor()
    }

    /// Whether the alternate screen buffer is active.
    pub fn alternate_screen(&self) -> bool {
        self.parser.screen().alternate_screen()
    }

    /// Whether the arrow keys should be encoded as application (`SS3`)
    /// sequences rather than the normal (`CSI`) ones (DECCKM).
    pub fn application_cursor(&self) -> bool {
        self.parser.screen().application_cursor()
    }

    /// Whether pasted text should be wrapped in bracketed-paste markers.
    pub fn bracketed_paste(&self) -> bool {
        self.parser.screen().bracketed_paste()
    }

    /// The terminal's window title, set by an OSC sequence. `vt100` 0.16.2
    /// reports this through a callback rather than storing it itself, so
    /// it's `TermCallbacks` that actually holds it.
    pub fn title(&self) -> &str {
        &self.parser.callbacks().title
    }

    /// Sets the scrollback view offset: `0` shows the live screen, and
    /// larger values look further back, up to the full depth of the
    /// history actually kept. Every row is marked changed, since the rows
    /// now in view are not the ones last drawn.
    ///
    /// `vt100` clamps the offset itself, against the real scrollback depth
    /// (`Screen::set_scrollback`: "The value given will be clamped to the
    /// actual size of the scrollback") — reading it back rather than
    /// trusting the caller's `lines` verbatim means a fresh grid with no
    /// history yet still counts as the live screen. An earlier fix round,
    /// against `vt100` 0.15.2, additionally clamped `lines` to at most the
    /// screen's own row count here: that version's view math
    /// (`Grid::visible_rows`) subtracted the offset from the row count
    /// without saturating, so anything past one screen height's worth of
    /// scrollback panicked on the next read regardless of how much real
    /// history backed it. 0.16.2 fixed this (`grid.rs`'s `visible_rows`
    /// now uses `saturating_sub`, with a comment noting the same case),
    /// confirmed directly: a 5-row screen fed 50 lines, scrolled back 30
    /// — well past 5 — reads the expected historic row with no panic. The
    /// extra clamp is gone; the whole history is reachable again.
    pub fn set_scrollback(&mut self, lines: usize) {
        self.parser.screen_mut().set_scrollback(lines);
        self.scrollback_offset = self.parser.screen().scrollback();
        self.rehash_all();
    }

    /// How far back the view is, in lines: `0` is the live screen. Read
    /// from `vt100` each time rather than kept from the last request,
    /// because `vt100` clamps a request to the history it has, and moves
    /// the offset on by itself as new lines scroll into history, so the
    /// view stays on the lines the reader scrolled to.
    pub fn scrollback(&self) -> usize {
        self.parser.screen().scrollback()
    }

    /// Hashes one row's visible contents and style, to detect whether it
    /// changed since the last hash.
    fn row_hash(&self, row: u16) -> u64 {
        let screen = self.parser.screen();
        let mut hasher = DefaultHasher::new();
        for col in 0..self.cols {
            match screen.cell(row, col) {
                Some(cell) => {
                    cell.contents().hash(&mut hasher);
                    hash_color(cell.fgcolor(), &mut hasher);
                    hash_color(cell.bgcolor(), &mut hasher);
                    cell.bold().hash(&mut hasher);
                    cell.italic().hash(&mut hasher);
                    cell.underline().hash(&mut hasher);
                    cell.inverse().hash(&mut hasher);
                    cell.is_wide().hash(&mut hasher);
                    cell.is_wide_continuation().hash(&mut hasher);
                }
                None => "".hash(&mut hasher),
            }
        }
        hasher.finish()
    }

    /// Recomputes every row's hash and marks every row changed. Used when
    /// the whole screen may have moved: construction, resize and scrolling.
    fn rehash_all(&mut self) {
        for row in 0..self.rows {
            self.row_hashes[row as usize] = self.row_hash(row);
            self.dirty.insert(row);
        }
    }

    /// Recomputes each row's hash after a feed, marking only the rows whose
    /// hash actually changed. Unlike `rehash_all`, this never forces a row
    /// dirty outright: a feed that clears the display (ED), or swaps to or
    /// from the alternate screen, is caught only because the affected
    /// rows' hashes end up different, not because we know structurally
    /// that a clear or a screen swap happened.
    fn rehash_changed(&mut self) {
        for row in 0..self.rows {
            let hash = self.row_hash(row);
            let idx = row as usize;
            if self.row_hashes[idx] != hash {
                self.row_hashes[idx] = hash;
                self.dirty.insert(row);
            }
        }
    }
}

/// The fewest rows `new`/`resize` will ever set. `vt100` still panics on
/// `process()` given a single-row grid and text that needs to wrap (an
/// underflow scrolling the cursor row onto a row that doesn't exist);
/// two rows gives it somewhere to scroll to. Columns have no such floor
/// beyond the general "at least one cell" rule. Confirmed still present
/// in 0.16.2, the version this crate is pinned to (`grid.rs:683`, the
/// upgrade from 0.15.2 that fixed the scrollback panic below did not
/// touch this one).
const MIN_ROWS: i32 = 2;

/// Clamps a caller-given size (`setup`/`resize` take Godot `int`s) into a
/// valid `vt100` grid dimension: at least `min`, and no more than
/// `u16::MAX`. Goes through `clamp` rather than `as`, so an out-of-range
/// `i32` — zero, negative, or past `u16::MAX` — never truncates or wraps
/// into some other, unrelated in-range `u16`; it lands on the nearest
/// valid edge instead.
fn clamp_dimension(value: i32, min: i32) -> u16 {
    let clamped = value.clamp(min, i32::from(u16::MAX));
    u16::try_from(clamped).expect("clamped within u16::MAX, and min is always >= 1")
}

/// Hashes a `vt100::Color` by its variant and any components, since `Color`
/// itself does not implement `Hash`.
fn hash_color(color: Color, hasher: &mut impl Hasher) {
    match color {
        Color::Default => 0u8.hash(hasher),
        Color::Idx(i) => {
            1u8.hash(hasher);
            i.hash(hasher);
        }
        Color::Rgb(r, g, b) => {
            2u8.hash(hasher);
            (r, g, b).hash(hasher);
        }
    }
}

/// The 16 standard ANSI colours, xterm's own conventional values, indices
/// 0-15: black, red, green, yellow, blue, magenta, cyan, white, then their
/// bright counterparts.
const ANSI_16: [(u8, u8, u8); 16] = [
    (0, 0, 0),
    (205, 0, 0),
    (0, 205, 0),
    (205, 205, 0),
    (0, 0, 238),
    (205, 0, 205),
    (0, 205, 205),
    (229, 229, 229),
    (127, 127, 127),
    (255, 0, 0),
    (0, 255, 0),
    (255, 255, 0),
    (92, 92, 255),
    (255, 0, 255),
    (0, 255, 255),
    (255, 255, 255),
];

/// Converts an xterm 256-colour index to RGB, computed from the standard
/// palette's formula rather than a 256-entry table: 0-15 are the
/// conventional ANSI colours above, 16-231 a 6x6x6 colour cube, and 232-255
/// a 24-step greyscale ramp.
fn xterm256(idx: u8) -> (u8, u8, u8) {
    match idx {
        0..=15 => ANSI_16[idx as usize],
        16..=231 => {
            let i = idx - 16;
            let r = i / 36;
            let g = (i / 6) % 6;
            let b = i % 6;
            let level = |c: u8| if c == 0 { 0 } else { 55 + c * 40 };
            (level(r), level(g), level(b))
        }
        232..=255 => {
            let level = 8 + (idx - 232) * 10;
            (level, level, level)
        }
    }
}

/// Converts a `vt100::Color` to RGBA, ready for a Godot `Color`. `Default`
/// becomes transparent black, so the style's own colour applies instead.
pub fn to_godot_rgba(color: Color) -> (u8, u8, u8, u8) {
    match color {
        Color::Default => (0, 0, 0, 0),
        Color::Idx(i) => {
            let (r, g, b) = xterm256(i);
            (r, g, b, 255)
        }
        Color::Rgb(r, g, b) => (r, g, b, 255),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Joins a row's runs into its plain text, for assertions.
    fn row_text(grid: &Grid, row: u16) -> String {
        grid.row_runs(row).iter().map(|r| r.text.as_str()).collect()
    }

    #[test]
    fn sgr_16_colour_sets_the_indexed_foreground() {
        let mut g = Grid::new(3, 1);
        g.feed(b"\x1b[31mR");
        assert_eq!(
            g.row_runs(0)[0].fg,
            Color::Idx(1),
            "SGR 31 is ANSI red, index 1"
        );
    }

    #[test]
    fn sgr_256_colour_sets_the_indexed_foreground() {
        let mut g = Grid::new(3, 1);
        g.feed(b"\x1b[38;5;208mR");
        assert_eq!(g.row_runs(0)[0].fg, Color::Idx(208));
    }

    #[test]
    fn sgr_true_colour_sets_an_rgb_background() {
        let mut g = Grid::new(3, 1);
        g.feed(b"\x1b[48;2;10;20;30mR");
        assert_eq!(g.row_runs(0)[0].bg, Color::Rgb(10, 20, 30));
    }

    #[test]
    fn runs_carry_their_start_column_and_cell_count_from_vt100_widths() {
        let mut g = Grid::new(20, 2);
        // An emoji and a CJK ideograph are two cells wide; the combining
        // acute joins the "e" before it in one cell.
        g.feed("ab🚀c\x1b[1m漢\x1b[0me\u{301}xy".as_bytes());
        let runs = g.row_runs(0);
        let shape: Vec<(&str, u16, u16)> = runs
            .iter()
            .map(|r| (r.text.as_str(), r.col, r.cells))
            .collect();
        assert_eq!(
            shape,
            vec![
                ("ab", 0, 2),
                ("🚀", 2, 2),
                ("c", 4, 1),
                ("漢", 5, 2),
                ("e\u{301}", 7, 1),
                ("xy          ", 8, 12),
            ],
            "each wide or combined cell a run of its own, at vt100's columns"
        );
        assert_eq!(
            runs.iter().map(|r| r.cells).sum::<u16>(),
            20,
            "the runs cover the row exactly"
        );
        assert_eq!(
            g.cursor(),
            (10, 0),
            "and the cursor is on the grid's column"
        );
    }

    #[test]
    fn bold_inverse_and_reset() {
        let mut g = Grid::new(3, 1);
        g.feed(b"\x1b[1;7mBI\x1b[0mN");
        let runs = g.row_runs(0);
        assert_eq!(runs.len(), 2, "the reset starts a new run: {runs:?}");
        assert_eq!(runs[0].text, "BI");
        assert!(runs[0].bold && runs[0].inverse);
        assert_eq!(runs[1].text, "N");
        assert!(!runs[1].bold && !runs[1].inverse);
    }

    #[test]
    fn cup_moves_the_cursor_to_a_row_and_column() {
        let mut g = Grid::new(10, 5);
        g.feed(b"\x1b[3;4H"); // 1-based row 3, column 4
        assert_eq!(g.cursor(), (3, 2), "0-based (col, row)");
    }

    #[test]
    fn cuu_cud_cuf_and_cub_move_the_cursor_relatively() {
        let mut g = Grid::new(10, 5);
        g.feed(b"\x1b[3;3H"); // 0-based (2, 2)
        g.feed(b"\x1b[1A");
        assert_eq!(g.cursor(), (2, 1), "CUU: up one row");
        g.feed(b"\x1b[2B");
        assert_eq!(g.cursor(), (2, 3), "CUD: down two rows");
        g.feed(b"\x1b[1C");
        assert_eq!(g.cursor(), (3, 3), "CUF: forward one column");
        g.feed(b"\x1b[2D");
        assert_eq!(g.cursor(), (1, 3), "CUB: back two columns");
    }

    #[test]
    fn decsc_decrc_saves_and_restores_the_cursor() {
        let mut g = Grid::new(10, 5);
        g.feed(b"\x1b[3;3H\x1b7"); // save at 0-based (2, 2)
        g.feed(b"\x1b[1;1H");
        assert_eq!(g.cursor(), (0, 0));
        g.feed(b"\x1b8"); // restore
        assert_eq!(g.cursor(), (2, 2));
    }

    #[test]
    fn el_erases_from_the_cursor_to_the_end_of_the_line() {
        let mut g = Grid::new(5, 1);
        g.feed(b"ABCDE\x1b[1;3H\x1b[K");
        assert_eq!(row_text(&g, 0), "AB   ");
    }

    #[test]
    fn ed_erases_the_whole_display() {
        let mut g = Grid::new(5, 2);
        g.feed(b"ABCDE\r\nFGHIJ\x1b[1;1H\x1b[2J");
        assert_eq!(row_text(&g, 0), "     ");
        assert_eq!(row_text(&g, 1), "     ");
    }

    #[test]
    fn clear_homes_the_cursor_and_erases_the_display() {
        let mut g = Grid::new(5, 2);
        g.feed(b"ABCDE\r\nFGHIJ\x1b[3;3H");
        g.feed(b"\x1b[H\x1b[2J"); // what a shell's `clear` sends
        assert_eq!(g.cursor(), (0, 0));
        assert_eq!(row_text(&g, 0), "     ");
        assert_eq!(row_text(&g, 1), "     ");
    }

    #[test]
    fn entering_and_leaving_the_alternate_screen_restores_the_primary_one() {
        let mut g = Grid::new(7, 1);
        g.feed(b"PRIMARY");
        assert!(!g.alternate_screen());
        g.feed(b"\x1b[?1049h");
        assert!(g.alternate_screen());
        g.feed(b"ALTERED");
        assert_eq!(row_text(&g, 0), "ALTERED");
        g.feed(b"\x1b[?1049l");
        assert!(!g.alternate_screen());
        assert_eq!(row_text(&g, 0), "PRIMARY", "the primary screen comes back");
    }

    #[test]
    fn a_wide_cjk_character_takes_two_cells() {
        let mut g = Grid::new(4, 1);
        g.feed("中AB".as_bytes());
        assert_eq!(row_text(&g, 0), "中AB");
    }

    #[test]
    fn a_wide_emoji_takes_two_cells() {
        let mut g = Grid::new(4, 1);
        g.feed("😀AB".as_bytes());
        assert_eq!(row_text(&g, 0), "😀AB");
    }

    #[test]
    fn changed_rows_reports_only_touched_rows_and_clears_on_read() {
        let mut g = Grid::new(5, 3);
        assert_eq!(
            g.take_changed_rows(),
            vec![0, 1, 2],
            "the first paint is the whole (blank) screen"
        );

        g.feed(b"\x1b[2;1Hhi"); // write on the second row
        assert_eq!(g.take_changed_rows(), vec![1]);

        assert_eq!(
            g.take_changed_rows(),
            Vec::<u16>::new(),
            "nothing changed since the last read"
        );
    }

    #[test]
    fn resize_keeps_existing_content() {
        let mut g = Grid::new(5, 2);
        g.feed(b"ABCDE\r\nFGHIJ");
        g.take_changed_rows();
        g.resize(8, 3);
        assert_eq!(g.size(), (8, 3));
        assert!(row_text(&g, 0).starts_with("ABCDE"));
        assert!(row_text(&g, 1).starts_with("FGHIJ"));
        assert_eq!(
            g.take_changed_rows(),
            vec![0, 1, 2],
            "a resize can reflow the whole screen"
        );
    }

    #[test]
    fn decckm_toggles_application_cursor() {
        let mut g = Grid::new(5, 1);
        assert!(!g.application_cursor());
        g.feed(b"\x1b[?1h");
        assert!(g.application_cursor());
        g.feed(b"\x1b[?1l");
        assert!(!g.application_cursor());
    }

    #[test]
    fn an_osc_sequence_sets_the_title() {
        let mut g = Grid::new(5, 1);
        g.feed(b"\x1b]0;Station Shell\x07");
        assert_eq!(g.title(), "Station Shell");
    }

    #[test]
    fn hiding_and_showing_the_cursor() {
        let mut g = Grid::new(5, 1);
        assert!(g.cursor_visible());
        g.feed(b"\x1b[?25l");
        assert!(!g.cursor_visible());
        g.feed(b"\x1b[?25h");
        assert!(g.cursor_visible());
    }

    #[test]
    fn bracketed_paste_mode_toggle() {
        let mut g = Grid::new(5, 1);
        assert!(!g.bracketed_paste());
        g.feed(b"\x1b[?2004h");
        assert!(g.bracketed_paste());
        g.feed(b"\x1b[?2004l");
        assert!(!g.bracketed_paste());
    }

    #[test]
    fn default_colour_maps_to_transparent() {
        assert_eq!(to_godot_rgba(Color::Default), (0, 0, 0, 0));
    }

    #[test]
    fn setup_and_resize_clamp_invalid_sizes_instead_of_panicking() {
        // Zero reaches `vt100` as an empty grid, which panics inside
        // `process()` (an unwrap in `screen.rs` that assumes a non-empty
        // row); values above `u16::MAX` cannot be represented at all.
        // `feed` not panicking is the assertion here.
        let mut g = Grid::new(0, 24);
        g.feed(b"hi");
        assert!(g.size().0 >= 1, "cols clamped to at least one");

        let mut g = Grid::new(80, 0);
        g.feed(b"hi");
        assert!(g.size().1 >= 2, "rows clamped to at least MIN_ROWS");

        let mut g = Grid::new(70_000, 24);
        g.feed(b"hi");
        assert_eq!(g.size().0, u16::MAX, "cols clamped down to u16::MAX");

        let mut g = Grid::new(10, 10);
        g.resize(0, 0);
        g.feed(b"hi");
        assert!(g.size().0 >= 1 && g.size().1 >= 1, "resize clamps too");

        let mut g = Grid::new(10, 10);
        g.resize(-5, -5);
        g.feed(b"hi");
        assert!(
            g.size().0 >= 1 && g.size().1 >= 2,
            "a negative resize clamps too"
        );
    }

    #[test]
    fn a_single_row_request_is_raised_to_avoid_a_vt100_wrapping_panic() {
        // vt100 0.16.2 (like 0.15.2 before it) panics on `process()` given
        // a genuinely single-row grid and text long enough to wrap: it
        // tries to scroll the cursor's row onto a row that doesn't exist
        // and underflows. This is the scenario directly, not just via a
        // zero/negative clamp.
        let mut g = Grid::new(1, 1);
        assert_eq!(g.size(), (1, 2), "rows raised to MIN_ROWS, cols left alone");
        g.feed(b"more text than a single cell can hold, forcing a wrap");

        let mut g = Grid::new(10, 10);
        g.resize(1, 1);
        assert_eq!(g.size(), (1, 2));
        g.feed(b"more text than a single cell can hold, forcing a wrap");
    }

    #[test]
    fn sizes_at_and_far_beyond_u16_max_clamp_to_it() {
        let mut g = Grid::new(65_536, 24); // one past u16::MAX
        g.feed(b"hi");
        assert_eq!(g.size().0, u16::MAX);

        let mut g = Grid::new(i32::MAX, 24);
        g.feed(b"hi");
        assert_eq!(g.size().0, u16::MAX, "i32::MAX clamps the same way");

        let mut g = Grid::new(80, i32::MAX);
        g.feed(b"hi");
        assert_eq!(g.size().1, u16::MAX, "the rows side too");
    }

    #[test]
    fn content_survives_a_resize_down_to_the_minimum_then_more_wrapping_text() {
        let mut g = Grid::new(20, 10);
        g.feed(b"hello world\r\nsecond line of text");

        g.resize(0, 0); // clamps to the minimum: 1 col, MIN_ROWS rows
        assert_eq!(g.size(), (1, 2));

        // The minimum grid is exactly the size that used to panic on
        // wrapping text (see the single-row test above); confirm the
        // chain of an ordinary resize down to it, then real use, holds.
        g.feed(b"more text than a single cell can hold, forcing a wrap");
    }

    #[test]
    fn resize_drops_dirty_rows_beyond_the_new_row_count() {
        let mut g = Grid::new(5, 5);
        g.take_changed_rows(); // clear the initial full-screen paint
        g.feed(b"\x1b[5;1Hrow4"); // touch row index 4 (the 5th row), left unread
        g.resize(5, 2);
        assert_eq!(
            g.take_changed_rows(),
            vec![0, 1],
            "rows beyond the new row count are dropped, not carried forward"
        );
    }

    #[test]
    fn scrolling_back_hides_the_live_cursor() {
        let mut g = Grid::new(5, 2);
        g.feed(b"LINE1\r\nLINE2\r\nLINE3\r\nLINE4\r\n");
        assert!(g.cursor_visible(), "visible at the live screen");

        g.set_scrollback(2);
        assert!(
            !g.cursor_visible(),
            "a real terminal hides the live cursor while showing history"
        );

        g.set_scrollback(0);
        assert!(g.cursor_visible(), "visible again back at the live screen");
    }

    #[test]
    fn scrollback_offset_reflects_the_history_vt100_actually_has_not_the_request() {
        let mut g = Grid::new(5, 2);
        // A fresh grid has no history at all: vt100 clamps the offset to 0,
        // so this must still count as the live screen.
        g.set_scrollback(5);
        assert!(
            g.cursor_visible(),
            "no history yet, so a scrollback request still lands on the live screen"
        );

        // 5 lines into a 2-row screen pushes about 3 lines into history.
        g.feed(b"L1\r\nL2\r\nL3\r\nL4\r\nL5\r\n");
        g.set_scrollback(1_000_000);
        assert!(
            !g.cursor_visible(),
            "clamped to the real (much smaller) history, which is still history"
        );

        g.set_scrollback(0);
        assert!(g.cursor_visible(), "visible again back at the live screen");
    }

    #[test]
    fn the_scrollback_offset_reads_the_clamp_and_follows_new_output() {
        let mut g = Grid::new(5, 2);
        g.feed(b"L1\r\nL2\r\nL3\r\nL4\r\nL5\r\n");
        g.set_scrollback(1_000_000);
        let deepest = g.scrollback();
        assert!(
            deepest > 0 && deepest < 10,
            "clamped to the history there is: {deepest}"
        );
        g.set_scrollback(1);
        g.feed(b"L6\r\nL7\r\n");
        assert_eq!(
            g.scrollback(),
            3,
            "new lines push the offset on, so the view keeps its lines"
        );
        g.set_scrollback(0);
        assert_eq!(g.scrollback(), 0, "the live screen");
    }

    #[test]
    fn scrolling_back_further_than_the_screen_height_does_not_panic() {
        // A fix round against `vt100` 0.15.2 clamped `set_scrollback`'s
        // request to the screen's own row count, working around a panic
        // in that version's view math for anything scrolled back further.
        // 0.16.2 fixed the underlying bug directly (see `set_scrollback`'s
        // doc comment), so this no longer needs the workaround to hold —
        // it's a plain regression guard now.
        let mut g = Grid::new(80, 5);
        let mut history = Vec::new();
        for i in 0..50 {
            history.extend_from_slice(format!("line {i}\r\n").as_bytes());
        }
        g.feed(&history);

        g.set_scrollback(1_000); // far more than 5, the screen's row count
        assert!(!g.cursor_visible(), "scrolled back into history");
        let _ = g.row_runs(0); // must not panic
        let _ = g.cursor();

        g.set_scrollback(0);
        assert!(g.cursor_visible(), "visible again back at the live screen");
    }

    #[test]
    fn scrolling_back_more_than_one_screen_height_reads_the_expected_historic_row() {
        // The whole history is reachable again now that 0.16.2 fixed the
        // panic the round-2 workaround guarded against: scrolling back
        // 30 lines on a 5-row screen — six screens' worth — lands well
        // past what the old clamp (to at most 5) would ever have shown.
        let mut g = Grid::new(20, 5);
        let mut history = Vec::new();
        for i in 0..50 {
            history.extend_from_slice(format!("line {i}\r\n").as_bytes());
        }
        g.feed(&history);

        g.set_scrollback(30);
        assert!(!g.cursor_visible(), "scrolled back into history");
        assert!(
            row_text(&g, 0).starts_with("line 16"),
            "row 0 thirty lines back: {:?}",
            row_text(&g, 0)
        );
    }

    #[test]
    fn scrolling_back_far_beyond_the_history_clamps_to_its_length_and_reads_the_first_line() {
        let mut g = Grid::new(20, 5);
        let mut history = Vec::new();
        for i in 0..50 {
            history.extend_from_slice(format!("line {i}\r\n").as_bytes());
        }
        g.feed(&history);

        g.set_scrollback(10_000); // far beyond the ~46 lines of real history
        assert!(!g.cursor_visible(), "scrolled back into history");
        assert!(
            row_text(&g, 0).starts_with("line 0"),
            "clamped to the real history's start: {:?}",
            row_text(&g, 0)
        );
    }

    #[test]
    fn scrolling_back_shows_history_in_row_runs() {
        let mut g = Grid::new(5, 2);
        g.feed(b"LINE1\r\nLINE2\r\nLINE3\r\nLINE4\r\n");
        let live_top = row_text(&g, 0);

        g.set_scrollback(2);
        let scrolled_top = row_text(&g, 0);
        assert_ne!(
            scrolled_top, live_top,
            "scrolling back shows different content than the live screen"
        );
        assert!(
            scrolled_top.starts_with("LINE1") || scrolled_top.starts_with("LINE2"),
            "history is visible while scrolled back: {scrolled_top:?}"
        );
    }

    #[test]
    fn changed_rows_reports_every_row_cleared_by_ed() {
        let mut g = Grid::new(5, 3);
        g.feed(b"AAAAA\r\nBBBBB\r\nCCCCC");
        g.take_changed_rows(); // clear the dirt from filling the screen

        g.feed(b"\x1b[1;1H\x1b[2J"); // erase in display: every row goes blank
        assert_eq!(
            g.take_changed_rows(),
            vec![0, 1, 2],
            "every row cleared by ED is reported changed"
        );
    }

    #[test]
    fn changed_rows_reports_every_row_touched_by_the_alternate_screen() {
        let mut g = Grid::new(5, 2);
        g.feed(b"AAAAA\r\nBBBBB");
        g.take_changed_rows();

        g.feed(b"\x1b[?1049h"); // enter the alternate screen: a blank buffer
        assert_eq!(
            g.take_changed_rows(),
            vec![0, 1],
            "the alternate screen's blank rows differ from the primary content"
        );

        g.feed(b"CCCCC");
        assert_eq!(
            g.take_changed_rows(),
            vec![0],
            "only the row actually written to changes"
        );

        g.feed(b"\x1b[?1049l"); // leave: the primary screen's old content returns
        assert_eq!(
            g.take_changed_rows(),
            vec![0, 1],
            "the restored primary screen differs from the alternate one"
        );
    }

    #[test]
    fn xterm256_cube_and_greyscale_are_computed_not_tabulated() {
        assert_eq!(
            to_godot_rgba(Color::Idx(196)),
            (255, 0, 0, 255),
            "the cube's bright-red corner"
        );
        assert_eq!(
            to_godot_rgba(Color::Idx(232)),
            (8, 8, 8, 255),
            "the first grey step"
        );
        assert_eq!(
            to_godot_rgba(Color::Idx(255)),
            (238, 238, 238, 255),
            "the last grey step"
        );
        assert_eq!(
            to_godot_rgba(Color::Idx(1)),
            (205, 0, 0, 255),
            "the base 16 use xterm's own values"
        );
    }
}
