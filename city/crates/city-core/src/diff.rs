//! Comparing two snapshots.

use city_contracts::{Change, Snapshot, SnapshotDiff};

/// What changed from `a` to `b`, occupant by occupant in ID order.
pub fn diff(a: &Snapshot, b: &Snapshot) -> SnapshotDiff {
    let mut changes = Vec::new();
    for (id, now) in &b.occupants {
        let Some(was) = a.occupants.get(id) else {
            changes.push(Change::OccupantAdded {
                occupant: id.clone(),
            });
            continue;
        };
        if was.location != now.location {
            changes.push(Change::LocationChanged {
                occupant: id.clone(),
                from: was.location.clone(),
                to: now.location.clone(),
            });
        }
        if was.shown != now.shown {
            changes.push(Change::PresenceChanged {
                occupant: id.clone(),
                from: was.shown,
                to: now.shown,
            });
        }
        if was.profile != now.profile {
            changes.push(Change::ProfileChanged {
                occupant: id.clone(),
            });
        }
    }
    SnapshotDiff {
        from_tick: a.tick,
        to_tick: b.tick,
        changes,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{World, synth::synthetic};
    use city_contracts::Change;

    #[test]
    fn diff_reports_location_and_presence_changes() {
        let (m, f) = synthetic(20, 1);
        let mut w = World::new(m, f, 1).unwrap();
        let a = w.snapshot().clone();
        w.run(10);
        let b = w.snapshot().clone();
        let d = diff(&a, &b);
        assert_eq!((d.from_tick, d.to_tick), (0, 10));
        assert!(
            d.changes
                .iter()
                .any(|c| matches!(c, Change::LocationChanged { .. }))
        );
        assert!(
            d.changes
                .iter()
                .any(|c| matches!(c, Change::PresenceChanged { .. }))
        );
        assert!(diff(&b, &b).changes.is_empty());
    }

    #[test]
    fn diff_reports_newcomers() {
        let (m, f) = synthetic(20, 1);
        let mut w = World::new(m, f, 1).unwrap();
        let a = w.snapshot().clone();
        w.run(25);
        let d = diff(&a, w.snapshot());
        assert!(
            d.changes
                .iter()
                .any(|c| matches!(c, Change::OccupantAdded { .. }))
        );
    }
}
