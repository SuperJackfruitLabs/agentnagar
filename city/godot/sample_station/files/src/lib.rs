//! Counting lines, words and characters, the way `wc` does.

/// What `count` found in one text.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct Counts {
    pub lines: usize,
    pub words: usize,
    pub chars: usize,
}

/// Counts `text`'s lines (its newlines, as `wc -l` does), its words (runs
/// separated by any whitespace) and its characters (not its bytes).
pub fn count(text: &str) -> Counts {
    Counts {
        lines: text.matches('\n').count(),
        words: text.split_whitespace().count(),
        chars: text.chars().count(),
    }
}
