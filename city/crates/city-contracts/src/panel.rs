//! The `sample` panel format: content a display shows before any product
//! feeds it live, bundled with the district fixture.

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

/// What a display shows. Every variant carries `sample`, true for the
/// bundled Part A content, so a viewer's "Sample" label follows the data,
/// not the source name.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum Panel {
    /// A noticeboard's dated notices.
    Notices {
        title: String,
        items: Vec<Notice>,
        sample: bool,
    },
    /// A bookshelf's spines.
    Shelf {
        title: String,
        spines: Vec<Spine>,
        sample: bool,
    },
    /// A plaque's fixed text.
    Plaque {
        title: String,
        text: String,
        sample: bool,
    },
}

/// One dated notice on a `Notices` panel.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Notice {
    pub date: String,
    pub headline: String,
    pub body: String,
}

/// One book on a `Shelf` panel.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Spine {
    pub title: String,
    pub subtitle: String,
}
