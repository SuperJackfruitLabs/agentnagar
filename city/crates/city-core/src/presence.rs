//! Honest presence: storing observations and deriving what is shown.

use city_contracts::{
    ConnectionState, Headline, Observation, Observed, OccupantKind, PresenceRecord, ProcessState,
    RejectReason, ShownConnection, ShownPresence, ShownProcess, ShownTask, Stamp, TaskState, Tick,
};

/// True from `expires_at` onwards: the bound is exclusive.
pub fn is_expired(stamp: &Stamp, now: Tick) -> bool {
    now >= stamp.expires_at
}

fn valid(stamp: &Stamp, now: Tick) -> bool {
    stamp.observed_at <= stamp.fetched_at
        && stamp.fetched_at < stamp.expires_at
        && stamp.observed_at <= now
}

/// Keeps whichever observation was observed later; on a tie the new one wins.
fn store<T>(slot: &mut Option<Observed<T>>, new: Observed<T>) -> bool {
    if let Some(held) = slot
        && held.stamp.observed_at > new.stamp.observed_at
    {
        return false;
    }
    *slot = Some(new);
    true
}

/// Validates an observation's stamp and stores it unless a newer one is held.
/// Returns `Ok(false)` when the observation was older and ignored.
pub fn apply_observation(
    rec: &mut PresenceRecord,
    obs: Observation,
    now: Tick,
) -> Result<bool, RejectReason> {
    let stamp = match &obs {
        Observation::Connection(o) => &o.stamp,
        Observation::Process(o) => &o.stamp,
        Observation::Task(o) => &o.stamp,
    };
    if !valid(stamp, now) {
        return Err(RejectReason::InvalidObservation);
    }
    Ok(match obs {
        Observation::Connection(o) => store(&mut rec.connection, o),
        Observation::Process(o) => store(&mut rec.process, o),
        Observation::Task(o) => store(&mut rec.task, o),
    })
}

/// What is shown for a presence record at `now`. An expired dimension is
/// `Stale`, never its last value; a missing one is `Unknown`.
pub fn derive_shown(kind: &OccupantKind, rec: &PresenceRecord, now: Tick) -> ShownPresence {
    let connection = match &rec.connection {
        None => ShownConnection::Unknown,
        Some(o) if is_expired(&o.stamp, now) => ShownConnection::Stale,
        Some(o) => match o.value {
            ConnectionState::Connected => ShownConnection::Connected,
            ConnectionState::Disconnected => ShownConnection::Disconnected,
            ConnectionState::Unknown => ShownConnection::Unknown,
        },
    };
    let process = match &rec.process {
        None => ShownProcess::Unknown,
        Some(o) if is_expired(&o.stamp, now) => ShownProcess::Stale,
        Some(o) => match o.value {
            ProcessState::Running => ShownProcess::Running,
            ProcessState::Stopped => ShownProcess::Stopped,
            ProcessState::Error => ShownProcess::Error,
            ProcessState::Unknown => ShownProcess::Unknown,
        },
    };
    let task = match &rec.task {
        None => ShownTask::Unknown,
        Some(o) if is_expired(&o.stamp, now) => ShownTask::Stale,
        Some(o) => match o.value.state {
            TaskState::Working => ShownTask::Working,
            TaskState::Waiting => ShownTask::Waiting,
            TaskState::Queued => ShownTask::Queued,
            TaskState::Idle => ShownTask::Idle,
            TaskState::Done => ShownTask::Done,
            TaskState::Unknown => ShownTask::Unknown,
        },
    };
    let headline = if matches!(kind, OccupantKind::Human { .. }) {
        match connection {
            ShownConnection::Connected => Headline::Present,
            ShownConnection::Disconnected => Headline::Offline,
            ShownConnection::Stale => Headline::Stale,
            ShownConnection::Unknown => Headline::Unknown,
        }
    } else if connection == ShownConnection::Disconnected || process == ShownProcess::Stopped {
        Headline::Offline
    } else if process == ShownProcess::Error {
        Headline::Error
    } else if connection == ShownConnection::Stale
        || process == ShownProcess::Stale
        || task == ShownTask::Stale
    {
        Headline::Stale
    } else if process != ShownProcess::Running {
        Headline::Unknown
    } else {
        match task {
            ShownTask::Working => Headline::Working,
            ShownTask::Waiting => Headline::Waiting,
            ShownTask::Queued => Headline::Queued,
            ShownTask::Idle => Headline::Idle,
            ShownTask::Done => Headline::Done,
            ShownTask::Unknown | ShownTask::Stale => Headline::Unknown,
        }
    };
    ShownPresence {
        headline,
        connection,
        process,
        task,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use city_contracts::*;

    fn st(o: u64, e: u64) -> Stamp {
        Stamp {
            observed_at: o,
            fetched_at: o,
            expires_at: e,
            source: "fixture".into(),
            source_version: "1".into(),
        }
    }
    fn agent() -> OccupantKind {
        OccupantKind::GuildAgent
    }
    fn running(o: u64, e: u64) -> Observation {
        Observation::Process(Observed {
            value: ProcessState::Running,
            stamp: st(o, e),
        })
    }
    fn task(s: TaskState, o: u64, e: u64) -> Observation {
        Observation::Task(Observed {
            value: TaskReport {
                state: s,
                summary: None,
                summary_public: false,
            },
            stamp: st(o, e),
        })
    }
    fn conn(c: ConnectionState, o: u64, e: u64) -> Observation {
        Observation::Connection(Observed {
            value: c,
            stamp: st(o, e),
        })
    }

    #[test]
    fn running_without_task_is_unknown_not_working() {
        let mut r = PresenceRecord::default();
        apply_observation(&mut r, running(0, 10), 0).unwrap();
        let s = derive_shown(&agent(), &r, 1);
        assert_eq!(s.task, ShownTask::Unknown);
        assert_eq!(s.headline, Headline::Unknown);
    }

    #[test]
    fn running_and_working_is_working() {
        let mut r = PresenceRecord::default();
        apply_observation(&mut r, running(0, 10), 0).unwrap();
        apply_observation(&mut r, task(TaskState::Working, 0, 10), 0).unwrap();
        assert_eq!(derive_shown(&agent(), &r, 1).headline, Headline::Working);
    }

    #[test]
    fn expired_task_is_stale_never_last_value() {
        let mut r = PresenceRecord::default();
        apply_observation(&mut r, running(0, 100), 0).unwrap();
        apply_observation(&mut r, task(TaskState::Working, 0, 5), 0).unwrap();
        assert_eq!(derive_shown(&agent(), &r, 4).task, ShownTask::Working);
        let s = derive_shown(&agent(), &r, 5);
        assert_eq!(s.task, ShownTask::Stale);
        assert_eq!(s.headline, Headline::Stale);
    }

    #[test]
    fn idle_stale_offline_unknown_are_distinct() {
        let mut idle = PresenceRecord::default();
        apply_observation(&mut idle, running(0, 9), 0).unwrap();
        apply_observation(&mut idle, task(TaskState::Idle, 0, 9), 0).unwrap();
        let mut off = PresenceRecord::default();
        apply_observation(&mut off, conn(ConnectionState::Disconnected, 0, 9), 0).unwrap();
        let hs = [
            derive_shown(&agent(), &idle, 1).headline,
            derive_shown(&agent(), &idle, 9).headline,
            derive_shown(&agent(), &off, 1).headline,
            derive_shown(&agent(), &PresenceRecord::default(), 1).headline,
        ];
        assert_eq!(
            hs,
            [
                Headline::Idle,
                Headline::Stale,
                Headline::Offline,
                Headline::Unknown
            ]
        );
    }

    #[test]
    fn stopped_and_error_processes() {
        let mut r = PresenceRecord::default();
        let p = |v| {
            Observation::Process(Observed {
                value: v,
                stamp: st(0, 9),
            })
        };
        apply_observation(&mut r, p(ProcessState::Stopped), 0).unwrap();
        assert_eq!(derive_shown(&agent(), &r, 1).headline, Headline::Offline);
        apply_observation(&mut r, p(ProcessState::Error), 0).unwrap();
        assert_eq!(derive_shown(&agent(), &r, 1).headline, Headline::Error);
    }

    #[test]
    fn older_observation_never_overwrites_newer() {
        let mut r = PresenceRecord::default();
        apply_observation(&mut r, running(0, 50), 6).unwrap();
        apply_observation(&mut r, task(TaskState::Done, 6, 50), 6).unwrap();
        assert_eq!(
            apply_observation(&mut r, task(TaskState::Working, 3, 50), 7),
            Ok(false)
        );
        assert_eq!(derive_shown(&agent(), &r, 7).task, ShownTask::Done);
    }

    #[test]
    fn rejects_impossible_stamps() {
        let mut r = PresenceRecord::default();
        assert_eq!(
            apply_observation(&mut r, running(5, 5), 5),
            Err(RejectReason::InvalidObservation)
        );
        assert_eq!(
            apply_observation(&mut r, running(9, 20), 5),
            Err(RejectReason::InvalidObservation)
        );
        let mut late_fetch = running(3, 20);
        if let Observation::Process(o) = &mut late_fetch {
            o.stamp.fetched_at = 2;
        }
        assert_eq!(
            apply_observation(&mut r, late_fetch, 5),
            Err(RejectReason::InvalidObservation)
        );
    }

    #[test]
    fn humans_show_present_from_connection() {
        let mut r = PresenceRecord::default();
        apply_observation(&mut r, conn(ConnectionState::Connected, 0, 9), 0).unwrap();
        let h = OccupantKind::Human {
            tier: HumanTier::Registered,
        };
        assert_eq!(derive_shown(&h, &r, 1).headline, Headline::Present);
        assert_eq!(derive_shown(&h, &r, 9).headline, Headline::Stale);
    }
}
