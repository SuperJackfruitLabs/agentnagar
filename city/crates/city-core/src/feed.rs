//! Parsing labelled presence feeds (JSON Lines).

use city_contracts::{FeedEntry, FeedHeader, FeedRecord, SCHEMA_VERSION};
use std::fmt;

/// A parsed feed: its header and its entries in tick order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Feed {
    pub header: FeedHeader,
    pub entries: Vec<FeedEntry>,
}

/// Why a feed could not be parsed. `line` is 1-based; 0 means the whole feed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FeedError {
    pub line: usize,
    pub message: String,
}

impl fmt::Display for FeedError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "line {}: {}", self.line, self.message)
    }
}

fn err(line: usize, message: impl Into<String>) -> FeedError {
    FeedError {
        line,
        message: message.into(),
    }
}

/// Parses a feed: one header first, then entries whose fixture flag matches
/// the header's and whose ticks never go backwards.
pub fn parse_feed(text: &str) -> Result<Feed, FeedError> {
    let mut header: Option<FeedHeader> = None;
    let mut entries: Vec<FeedEntry> = Vec::new();
    for (i, raw) in text.lines().enumerate() {
        let line = i + 1;
        if raw.trim().is_empty() {
            continue;
        }
        let record: FeedRecord =
            serde_json::from_str(raw).map_err(|e| err(line, format!("not a feed record: {e}")))?;
        match (record, &header) {
            (FeedRecord::Header(h), None) => {
                if h.schema_version != SCHEMA_VERSION {
                    return Err(err(
                        line,
                        format!(
                            "schema version {} is not the supported version {SCHEMA_VERSION}",
                            h.schema_version
                        ),
                    ));
                }
                header = Some(h);
            }
            (FeedRecord::Header(_), Some(_)) => {
                return Err(err(line, "a feed has exactly one header"));
            }
            (FeedRecord::Entry(_), None) => {
                return Err(err(line, "the first record must be the header"));
            }
            (FeedRecord::Entry(e), Some(h)) => {
                if e.fixture != h.fixture {
                    return Err(err(
                        line,
                        format!(
                            "entry fixture flag {} does not match the header's {}",
                            e.fixture, h.fixture
                        ),
                    ));
                }
                if let Some(prev) = entries.last()
                    && e.at < prev.at
                {
                    return Err(err(
                        line,
                        format!("tick {} comes after tick {}", e.at, prev.at),
                    ));
                }
                entries.push(e);
            }
        }
    }
    let header = header.ok_or_else(|| err(0, "the feed has no header"))?;
    Ok(Feed { header, entries })
}

#[cfg(test)]
mod tests {
    use super::*;

    const H: &str = r#"{"record":"header","schema_version":1,"source":"fixture:t","fixture":true}"#;

    fn depart(at: u64, fixture: bool) -> String {
        format!(
            r#"{{"record":"entry","at":{at},"fixture":{fixture},"command":{{"type":"Depart","occupant":"agent:kai"}}}}"#
        )
    }

    #[test]
    fn parses_header_and_entries() {
        let f = parse_feed(&format!(
            "{H}\n\n{}\n{}\n",
            depart(0, true),
            depart(2, true)
        ))
        .unwrap();
        assert!(f.header.fixture);
        assert_eq!(f.entries.len(), 2);
        assert_eq!(f.entries[1].at, 2);
    }

    #[test]
    fn requires_header_first() {
        let e = parse_feed(&depart(0, true)).unwrap_err();
        assert_eq!(e.line, 1);
    }

    #[test]
    fn rejects_mixed_fixture_flags() {
        let e = parse_feed(&format!("{H}\n{}", depart(0, false))).unwrap_err();
        assert_eq!(e.line, 2);
        assert!(e.message.contains("fixture"));
    }

    #[test]
    fn rejects_out_of_order_ticks() {
        let e = parse_feed(&format!("{H}\n{}\n{}", depart(5, true), depart(4, true))).unwrap_err();
        assert_eq!(e.line, 3);
    }

    #[test]
    fn rejects_second_header_and_bad_json() {
        assert_eq!(parse_feed(&format!("{H}\n{H}")).unwrap_err().line, 2);
        assert_eq!(parse_feed(&format!("{H}\nnot json")).unwrap_err().line, 2);
    }

    #[test]
    fn rejects_empty_feed_and_wrong_version() {
        assert_eq!(parse_feed("\n").unwrap_err().line, 0);
        let old = H.replace("\"schema_version\":1", "\"schema_version\":2");
        assert_eq!(parse_feed(&old).unwrap_err().line, 1);
    }
}
