//! Small helpers for walking occupants.

use city_contracts::{CityId, Tick};

/// Degrees clockwise from north for one grid step, rounded to 45°.
pub fn facing_of(di: i32, dj: i32) -> i32 {
    match (di.signum(), dj.signum()) {
        (0, -1) => 0,
        (1, -1) => 45,
        (1, 0) => 90,
        (1, 1) => 135,
        (0, 1) => 180,
        (-1, 1) => 225,
        (-1, 0) => 270,
        (-1, -1) => 315,
        _ => 0,
    }
}

/// `tan((k + 0.5)°)` for `k` in `0..45`, scaled by 10⁹: the boundaries
/// between whole degrees, for [`heading_of`].
const TAN_HALF_DEGREES: [i128; 45] = [
    8726868, 26185922, 43660943, 61162620, 78701707, 96289048, 113935608, 131652498, 149451001,
    167342609, 185339045, 203452299, 221694663, 240078759, 258617584, 277324544, 296213495,
    315298789, 334595320, 354118573, 373884679, 393910476, 414213562, 434812375, 455726256,
    476975533, 498581608, 520567051, 542955700, 565772778, 589045016, 612800788, 637070261,
    661885561, 687280959, 713293068, 739961075, 767326988, 795435917, 824336386, 854080685,
    884725265, 916331174, 948964567, 982697263,
];

/// The whole degrees, 0 to 45, nearest the angle whose tangent is
/// `across / along`, for `0 <= across <= along`.
fn octant_degrees(across: i128, along: i128) -> i32 {
    if along == 0 {
        return 0;
    }
    TAN_HALF_DEGREES
        .iter()
        .take_while(|&&t| across * 1_000_000_000 > along * t)
        .count() as i32
}

/// Degrees clockwise from north, 0 to 359, of the direction `(dx, dz)` on
/// the ground (`x` east, `z` south), to the nearest whole degree; 0 for no
/// direction. The same convention as [`facing_of`], in integers only.
pub fn heading_of(dx: i64, dz: i64) -> i32 {
    let (east, north) = (i128::from(dx), -i128::from(dz));
    let (a, b) = (east.abs(), north.abs());
    let from_north = if a <= b {
        octant_degrees(a, b)
    } else {
        90 - octant_degrees(b, a)
    };
    let degrees = match (east >= 0, north >= 0) {
        (true, true) => from_north,
        (true, false) => 180 - from_north,
        (false, false) => 180 + from_north,
        (false, true) => 360 - from_north,
    };
    degrees % 360
}

/// A stable choice for one occupant at one tick, independent of anyone
/// else: FNV-1a over the seed, the city ID and the tick. Standing spots use
/// it instead of the shared random stream, so no occupant's choice can shift
/// another's.
pub fn spot_hash(seed: u64, id: &CityId, tick: Tick) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    let bytes = seed
        .to_le_bytes()
        .into_iter()
        .chain(id.as_str().bytes())
        .chain(tick.to_le_bytes());
    for b in bytes {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x0100_0000_01b3);
    }
    h
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn headings_follow_the_compass_to_the_degree() {
        assert_eq!(heading_of(0, 0), 0);
        assert_eq!(heading_of(0, -5), 0);
        assert_eq!(heading_of(5, 0), 90);
        assert_eq!(heading_of(0, 5), 180);
        assert_eq!(heading_of(-5, 0), 270);
        assert_eq!(heading_of(3, -3), 45);
        assert_eq!(heading_of(-3, 3), 225);
        assert_eq!(heading_of(-1, -1), 315);
        // 30° east of north: tan 30° = 0.577.
        assert_eq!(heading_of(577, -1000), 30);
        assert_eq!(heading_of(1000, -577), 60);
        assert_eq!(heading_of(577, 1000), 150);
        assert_eq!(heading_of(-577, -1000), 330);
        assert_eq!(heading_of(1, -1_000_000), 0);
        assert_eq!(heading_of(-1, -1_000_000), 0, "359.99° rounds to 0");
        // Agrees with facing_of on every grid step.
        for (di, dj) in [
            (0, -1),
            (1, -1),
            (1, 0),
            (1, 1),
            (0, 1),
            (-1, 1),
            (-1, 0),
            (-1, -1),
        ] {
            assert_eq!(heading_of(di.into(), dj.into()), facing_of(di, dj));
        }
    }

    #[test]
    fn facings_follow_the_compass() {
        assert_eq!(facing_of(0, -1), 0);
        assert_eq!(facing_of(1, 0), 90);
        assert_eq!(facing_of(0, 1), 180);
        assert_eq!(facing_of(-1, -1), 315);
    }

    #[test]
    fn spot_hash_is_stable_and_varies() {
        let a = CityId::from("agent:a");
        assert_eq!(spot_hash(1, &a, 5), spot_hash(1, &a, 5));
        assert_ne!(spot_hash(1, &a, 5), spot_hash(1, &a, 6));
        assert_ne!(
            spot_hash(1, &a, 5),
            spot_hash(1, &CityId::from("agent:b"), 5)
        );
    }
}
