//! Honest presence: observations in, shown presence out.

use crate::Tick;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum ConnectionState {
    Connected,
    Disconnected,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum ProcessState {
    Running,
    Stopped,
    Error,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum TaskState {
    Working,
    Waiting,
    Queued,
    Idle,
    Done,
    Unknown,
}

/// When and where an observation came from, in simulation time.
/// `expires_at` is exclusive: at that tick the observation is already stale.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Stamp {
    pub observed_at: Tick,
    pub fetched_at: Tick,
    pub expires_at: Tick,
    pub source: String,
    pub source_version: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct TaskReport {
    pub state: TaskState,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub summary: Option<String>,
    /// Summaries are private unless explicitly marked public.
    #[serde(default)]
    pub summary_public: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Observed<T> {
    pub value: T,
    pub stamp: Stamp,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "dimension")]
pub enum Observation {
    Connection(Observed<ConnectionState>),
    Process(Observed<ProcessState>),
    Task(Observed<TaskReport>),
}

/// The latest observation held for each dimension.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct PresenceRecord {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub connection: Option<Observed<ConnectionState>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub process: Option<Observed<ProcessState>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub task: Option<Observed<TaskReport>>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum ShownConnection {
    Connected,
    Disconnected,
    #[default]
    Unknown,
    Stale,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum ShownProcess {
    Running,
    Stopped,
    Error,
    #[default]
    Unknown,
    Stale,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum ShownTask {
    Working,
    Waiting,
    Queued,
    Idle,
    Done,
    #[default]
    Unknown,
    Stale,
}

/// The single state a renderer shows first.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum Headline {
    Working,
    Waiting,
    Queued,
    Idle,
    Done,
    /// A connected human.
    Present,
    Offline,
    Error,
    Stale,
    #[default]
    Unknown,
}

/// What the core shows, derived from a presence record at a tick.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ShownPresence {
    pub headline: Headline,
    pub connection: ShownConnection,
    pub process: ShownProcess,
    pub task: ShownTask,
}

#[derive(
    Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, JsonSchema,
)]
pub enum Dimension {
    Connection,
    Process,
    Task,
}
