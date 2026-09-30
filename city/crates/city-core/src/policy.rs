//! Named, replaceable seat-assignment rules.

pub use crate::index::SeatInfo;
use city_contracts::{PlaceId, SeatPolicyName};
use std::cmp::Reverse;
use std::collections::BTreeMap;

/// Chooses a seat from `free`: the room's hot seats with no holder.
pub fn choose_seat(
    policy: SeatPolicyName,
    department: Option<&str>,
    free: &[&SeatInfo],
) -> Option<PlaceId> {
    match policy {
        SeatPolicyName::DepartmentFirst => department_first(department, free),
    }
}

/// Prefer the occupant's department pod, then the pod with most free seats,
/// then the lowest seat ID. A seat with no pod is a pod of one.
fn department_first(department: Option<&str>, free: &[&SeatInfo]) -> Option<PlaceId> {
    let own: Vec<&SeatInfo> = free
        .iter()
        .copied()
        .filter(|s| {
            s.pod.is_some() && department.is_some() && s.department.as_deref() == department
        })
        .collect();
    let candidates: Vec<&SeatInfo> = if own.is_empty() { free.to_vec() } else { own };
    let mut per_pod: BTreeMap<&PlaceId, u32> = BTreeMap::new();
    for s in &candidates {
        if let Some(pod) = &s.pod {
            *per_pod.entry(pod).or_default() += 1;
        }
    }
    candidates
        .iter()
        .min_by_key(|s| {
            let free_in_pod = s.pod.as_ref().map_or(1, |p| per_pod[p]);
            (Reverse(free_in_pod), &s.id)
        })
        .map(|s| s.id.clone())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn s(id: &str, pod: Option<&str>, dept: Option<&str>) -> SeatInfo {
        SeatInfo {
            id: id.into(),
            pod: pod.map(Into::into),
            department: dept.map(Into::into),
            reserved_for: None,
            ..Default::default()
        }
    }

    #[test]
    fn prefers_own_department_pod() {
        let (a, b, c) = (
            s("seat:1", Some("pod:k"), Some("knowledge")),
            s("seat:2", Some("pod:m"), Some("making")),
            s("seat:3", Some("pod:k"), Some("knowledge")),
        );
        assert_eq!(
            choose_seat(
                SeatPolicyName::DepartmentFirst,
                Some("making"),
                &[&a, &b, &c]
            ),
            Some("seat:2".into())
        );
    }

    #[test]
    fn otherwise_pod_with_most_free_seats() {
        let (a, b, c) = (
            s("seat:1", Some("pod:x"), None),
            s("seat:2", Some("pod:y"), None),
            s("seat:3", Some("pod:y"), None),
        );
        assert_eq!(
            choose_seat(
                SeatPolicyName::DepartmentFirst,
                Some("making"),
                &[&a, &b, &c]
            ),
            Some("seat:2".into())
        );
    }

    #[test]
    fn ties_break_on_lowest_seat_id() {
        let (a, b) = (s("seat:2", None, None), s("seat:1", None, None));
        assert_eq!(
            choose_seat(SeatPolicyName::DepartmentFirst, None, &[&a, &b]),
            Some("seat:1".into())
        );
    }

    #[test]
    fn no_free_seat_means_none() {
        assert_eq!(
            choose_seat(SeatPolicyName::DepartmentFirst, None, &[]),
            None
        );
    }
}
