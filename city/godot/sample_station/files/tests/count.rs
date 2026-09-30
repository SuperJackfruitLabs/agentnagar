use tally::{count, Counts};

#[test]
fn empty_text_counts_nothing() {
    assert_eq!(count(""), Counts::default());
}

#[test]
fn counts_lines_by_their_newlines() {
    assert_eq!(count("one\ntwo\n").lines, 2);
}

#[test]
fn counts_words_split_by_spaces() {
    assert_eq!(count("one two  three").words, 3);
}

#[test]
fn counts_characters_not_bytes() {
    assert_eq!(count("café").chars, 4);
}

#[test]
fn counts_words_split_by_tabs() {
    assert_eq!(count("one\ttwo\tthree").words, 3);
}

#[test]
fn blank_lines_hold_no_words() {
    assert_eq!(count("\n\n\n").words, 0);
}

#[test]
fn text_that_is_not_utf8_still_counts() {
    let bytes = include_bytes!("fixtures/latin1.txt");
    let text = String::from_utf8_lossy(bytes);
    assert_eq!(count(&text).words, 2);
}
