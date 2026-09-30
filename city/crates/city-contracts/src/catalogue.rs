//! The catalogue of kinds: what each thing is and how much ground it takes.
//!
//! The catalogue is versioned data, embedded into the build from
//! `city/catalogue/catalogue.json`. A manifest names the catalogue version it
//! was written against; the core refuses a version it does not carry. A
//! later reviewed asset is a new kind in a new catalogue version, so it
//! needs no new code here.

use crate::Point;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::sync::OnceLock;

/// The catalogue of kinds, as parsed from `catalogue.json`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Catalogue {
    pub version: u32,
    pub kinds: Vec<Kind>,
}

/// One kind of thing a placement can be: how much ground it takes, where its
/// anchors sit, and what it offers.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Kind {
    /// Kebab-case, such as `desk` or `guild-hall`. Style packs map this to
    /// their art.
    pub id: String,
    pub name: String,
    pub description: String,
    pub class: Class,
    /// Shapes in the kind's own frame (cm, origin at the placement point,
    /// facing 0 north). The ground this kind takes in the walking band.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub footprint: Vec<Shape>,
    /// Shapes that do not block walking, such as tall grass or curtains. A
    /// shape is in `footprint` or `soft`, never both. A sized kind with soft
    /// shapes and no footprint (a meadow) has its placement's size in place
    /// of them: soft ground filling the size (see [`Kind::sized_soft`]).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub soft: Vec<Shape>,
    /// When true, a placement gives its own `size`: one rect centred on the
    /// point. It replaces the footprint, so it blocks walking (a block's
    /// lot), except for a kind that declares soft shapes and no footprint,
    /// whose soft shapes it replaces instead, so it blocks nothing (a
    /// meadow). A sized kind has no anchors.
    #[serde(default)]
    pub sized: bool,
    /// The step, in centimetres, a placement's point must lie on.
    pub snap: i32,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub anchors: Vec<Anchor>,
    /// The actions this kind offers, named from the vision's reusable
    /// capabilities (validated by [`Kind::issues`]). `inspect` and `watch`
    /// (looking over a workstation user's shoulder) are the client's
    /// alone; the core keeps `sit`, `read`, `use`, `board` and `enter`.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub capabilities: Vec<Capability>,
    /// The state fields an instance of this kind may hold.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub state: Vec<StateField>,
    /// The top of the solid part (cm). Packs are told it; it has no effect
    /// on the grid.
    pub height: i32,
    /// A building's shell thickness (cm).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wall: Option<i32>,
    /// A building's exterior door opening (cm).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub door_width: Option<i32>,
    /// A vehicle's width (cm).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub width: Option<i32>,
}

/// Which rules apply to a kind.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "kebab-case")]
pub enum Class {
    Furniture,
    Seat,
    Fixture,
    Planting,
    Block,
    Building,
    Vehicle,
}

/// A shape in a kind's own frame, in centimetres. Distinguished by its
/// fields, not a tag: a rect carries `w`/`d`, a disc carries `r`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(untagged)]
pub enum Shape {
    Rect { x: i32, z: i32, w: i32, d: i32 },
    Disc { x: i32, z: i32, r: i32 },
}

/// A typed connection point in a kind's own frame.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Anchor {
    #[serde(rename = "type")]
    pub kind: AnchorType,
    pub at: Point,
    /// Degrees clockwise from north, in the kind's frame. For `sit`, `use`
    /// and `stand` anchors, the way the user faces there; for a `display`,
    /// the surface's outward normal, so readers stand in front of it and
    /// face it the opposite way.
    #[serde(default)]
    pub facing: i32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub height: Option<i32>,
    /// A display anchor's surface size.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub size: Option<Size>,
}

/// What an anchor is for: where one steps in or on (`Enter`), a seat's point
/// (`Sit`), where one stands or sits to use something (`Use`), a surface
/// that shows content (`Display`), or a place to wait or watch (`Stand`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum AnchorType {
    Enter,
    Sit,
    Use,
    Display,
    Stand,
}

/// An action a kind offers, and the type of anchor it happens at.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Capability {
    pub name: String,
    /// The anchor type the action happens at. Only `inspect` may name
    /// none, since it looks at the placement itself and changes nothing.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub at: Option<AnchorType>,
}

/// The capability names a kind may offer, from the vision's reusable
/// capabilities, and `watch`, the interactions spec's own. Only some have
/// behaviour today (see city-core `interact`).
pub const KNOWN_CAPABILITIES: [&str; 10] = [
    "inspect", "sit", "use", "read", "open", "board", "carry", "store", "write", "watch",
];

/// The one capability that may name no anchor.
pub const INSPECT: &str = "inspect";

/// A state field an instance of a kind may hold, with its type and default.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct StateField {
    pub name: String,
    #[serde(rename = "type")]
    pub ty: StateType,
    pub default: serde_json::Value,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum StateType {
    Bool,
    Int,
    Text,
    Ref,
}

/// A size in centimetres: a display anchor's surface, or a sized
/// placement's footprint.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Size {
    pub w: i32,
    pub d: i32,
}

impl Catalogue {
    /// The catalogue built into this binary, parsed once.
    pub fn builtin() -> &'static Catalogue {
        static CATALOGUE: OnceLock<Catalogue> = OnceLock::new();
        CATALOGUE.get_or_init(|| {
            serde_json::from_str(include_str!("../../../catalogue/catalogue.json"))
                .expect("built-in catalogue.json parses")
        })
    }

    /// The kind with this ID, if the catalogue carries one.
    pub fn kind(&self, id: &str) -> Option<&Kind> {
        self.kinds.iter().find(|k| k.id == id)
    }

    /// What is wrong with the catalogue's kinds, one sentence each; empty
    /// when nothing is. Each kind's problems come in its order (see
    /// [`Kind::issues`]), and a kind ID used twice is one more.
    pub fn issues(&self) -> Vec<String> {
        let mut out = Vec::new();
        for (k, kind) in self.kinds.iter().enumerate() {
            if self.kinds[..k].iter().any(|other| other.id == kind.id) {
                out.push(format!("Kind {} is listed twice.", kind.id));
            }
            out.extend(kind.issues());
        }
        out
    }
}

impl Kind {
    /// What is wrong with this kind, one sentence each: a capability of an
    /// unknown name, one that names no anchor although it is not `inspect`,
    /// or one at an anchor type the kind has no anchor of; a shape both
    /// solid and soft; a sized kind with anchors, whose places could not
    /// follow its size.
    pub fn issues(&self) -> Vec<String> {
        let mut out = Vec::new();
        for c in &self.capabilities {
            if !KNOWN_CAPABILITIES.contains(&c.name.as_str()) {
                out.push(format!(
                    "{} offers {}, which is not a known capability.",
                    self.id, c.name
                ));
            }
            match c.at {
                None if c.name != INSPECT => out.push(format!(
                    "{} offers {} at no anchor; only {INSPECT} may name none.",
                    self.id, c.name
                )),
                Some(at) if !self.anchors.iter().any(|a| a.kind == at) => out.push(format!(
                    "{} offers {} at a {at:?} anchor, but has none.",
                    self.id, c.name
                )),
                _ => {}
            }
        }
        if self.footprint.iter().any(|s| self.soft.contains(s)) {
            out.push(format!("{} has a shape both solid and soft.", self.id));
        }
        if self.sized && !self.anchors.is_empty() {
            out.push(format!(
                "{} is sized and has anchors, which do not move with its size.",
                self.id
            ));
        }
        out
    }

    /// Whether a sized placement of this kind is soft ground: a kind that
    /// declares soft shapes and no footprint (a meadow) takes its size as
    /// soft, blocking nothing; any other sized kind takes it as its solid
    /// footprint (a block's lot).
    pub fn sized_soft(&self) -> bool {
        self.sized && self.footprint.is_empty() && !self.soft.is_empty()
    }
}
