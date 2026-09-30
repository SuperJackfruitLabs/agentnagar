use std::io::{self, Read};

fn main() -> io::Result<()> {
    let mut input = Vec::new();
    io::stdin().read_to_end(&mut input)?;
    let text = String::from_utf8_lossy(&input);
    let counts = tally::count(&text);
    // The same order as `wc`: lines, words, then characters.
    println!("{:>7} {:>7} {:>7}", counts.lines, counts.words, counts.chars);
    Ok(())
}
