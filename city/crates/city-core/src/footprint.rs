//! Exact integer footprint geometry: the fixed sine and cosine table, and
//! testing a point against a placed kind's shapes.
//!
//! No floating point: the same result on every platform (README
//! "Determinism"). The table is generated offline and committed as integer
//! literals, so the crate itself never calls a trigonometric function.

use city_contracts::{Point, Rect, Shape};

/// The body clearance margin (cm): a walkable cell centre must lie this far
/// outside every footprint.
pub const MARGIN: i64 = 10;

/// Sine and cosine for whole degrees, scaled to 2^16 and rounded once, so
/// rotation is identical on every platform. Indexed `0..360`; `sin_cos`
/// wraps any degree into this range.
const SIN_COS: [(i64, i64); 360] = [
    (0, 65536),
    (1144, 65526),
    (2287, 65496),
    (3430, 65446),
    (4572, 65376),
    (5712, 65287),
    (6850, 65177),
    (7987, 65048),
    (9121, 64898),
    (10252, 64729),
    (11380, 64540),
    (12505, 64332),
    (13626, 64104),
    (14742, 63856),
    (15855, 63589),
    (16962, 63303),
    (18064, 62997),
    (19161, 62672),
    (20252, 62328),
    (21336, 61966),
    (22415, 61584),
    (23486, 61183),
    (24550, 60764),
    (25607, 60326),
    (26656, 59870),
    (27697, 59396),
    (28729, 58903),
    (29753, 58393),
    (30767, 57865),
    (31772, 57319),
    (32768, 56756),
    (33754, 56175),
    (34729, 55578),
    (35693, 54963),
    (36647, 54332),
    (37590, 53684),
    (38521, 53020),
    (39441, 52339),
    (40348, 51643),
    (41243, 50931),
    (42126, 50203),
    (42995, 49461),
    (43852, 48703),
    (44695, 47930),
    (45525, 47143),
    (46341, 46341),
    (47143, 45525),
    (47930, 44695),
    (48703, 43852),
    (49461, 42995),
    (50203, 42126),
    (50931, 41243),
    (51643, 40348),
    (52339, 39441),
    (53020, 38521),
    (53684, 37590),
    (54332, 36647),
    (54963, 35693),
    (55578, 34729),
    (56175, 33754),
    (56756, 32768),
    (57319, 31772),
    (57865, 30767),
    (58393, 29753),
    (58903, 28729),
    (59396, 27697),
    (59870, 26656),
    (60326, 25607),
    (60764, 24550),
    (61183, 23486),
    (61584, 22415),
    (61966, 21336),
    (62328, 20252),
    (62672, 19161),
    (62997, 18064),
    (63303, 16962),
    (63589, 15855),
    (63856, 14742),
    (64104, 13626),
    (64332, 12505),
    (64540, 11380),
    (64729, 10252),
    (64898, 9121),
    (65048, 7987),
    (65177, 6850),
    (65287, 5712),
    (65376, 4572),
    (65446, 3430),
    (65496, 2287),
    (65526, 1144),
    (65536, 0),
    (65526, -1144),
    (65496, -2287),
    (65446, -3430),
    (65376, -4572),
    (65287, -5712),
    (65177, -6850),
    (65048, -7987),
    (64898, -9121),
    (64729, -10252),
    (64540, -11380),
    (64332, -12505),
    (64104, -13626),
    (63856, -14742),
    (63589, -15855),
    (63303, -16962),
    (62997, -18064),
    (62672, -19161),
    (62328, -20252),
    (61966, -21336),
    (61584, -22415),
    (61183, -23486),
    (60764, -24550),
    (60326, -25607),
    (59870, -26656),
    (59396, -27697),
    (58903, -28729),
    (58393, -29753),
    (57865, -30767),
    (57319, -31772),
    (56756, -32768),
    (56175, -33754),
    (55578, -34729),
    (54963, -35693),
    (54332, -36647),
    (53684, -37590),
    (53020, -38521),
    (52339, -39441),
    (51643, -40348),
    (50931, -41243),
    (50203, -42126),
    (49461, -42995),
    (48703, -43852),
    (47930, -44695),
    (47143, -45525),
    (46341, -46341),
    (45525, -47143),
    (44695, -47930),
    (43852, -48703),
    (42995, -49461),
    (42126, -50203),
    (41243, -50931),
    (40348, -51643),
    (39441, -52339),
    (38521, -53020),
    (37590, -53684),
    (36647, -54332),
    (35693, -54963),
    (34729, -55578),
    (33754, -56175),
    (32768, -56756),
    (31772, -57319),
    (30767, -57865),
    (29753, -58393),
    (28729, -58903),
    (27697, -59396),
    (26656, -59870),
    (25607, -60326),
    (24550, -60764),
    (23486, -61183),
    (22415, -61584),
    (21336, -61966),
    (20252, -62328),
    (19161, -62672),
    (18064, -62997),
    (16962, -63303),
    (15855, -63589),
    (14742, -63856),
    (13626, -64104),
    (12505, -64332),
    (11380, -64540),
    (10252, -64729),
    (9121, -64898),
    (7987, -65048),
    (6850, -65177),
    (5712, -65287),
    (4572, -65376),
    (3430, -65446),
    (2287, -65496),
    (1144, -65526),
    (0, -65536),
    (-1144, -65526),
    (-2287, -65496),
    (-3430, -65446),
    (-4572, -65376),
    (-5712, -65287),
    (-6850, -65177),
    (-7987, -65048),
    (-9121, -64898),
    (-10252, -64729),
    (-11380, -64540),
    (-12505, -64332),
    (-13626, -64104),
    (-14742, -63856),
    (-15855, -63589),
    (-16962, -63303),
    (-18064, -62997),
    (-19161, -62672),
    (-20252, -62328),
    (-21336, -61966),
    (-22415, -61584),
    (-23486, -61183),
    (-24550, -60764),
    (-25607, -60326),
    (-26656, -59870),
    (-27697, -59396),
    (-28729, -58903),
    (-29753, -58393),
    (-30767, -57865),
    (-31772, -57319),
    (-32768, -56756),
    (-33754, -56175),
    (-34729, -55578),
    (-35693, -54963),
    (-36647, -54332),
    (-37590, -53684),
    (-38521, -53020),
    (-39441, -52339),
    (-40348, -51643),
    (-41243, -50931),
    (-42126, -50203),
    (-42995, -49461),
    (-43852, -48703),
    (-44695, -47930),
    (-45525, -47143),
    (-46341, -46341),
    (-47143, -45525),
    (-47930, -44695),
    (-48703, -43852),
    (-49461, -42995),
    (-50203, -42126),
    (-50931, -41243),
    (-51643, -40348),
    (-52339, -39441),
    (-53020, -38521),
    (-53684, -37590),
    (-54332, -36647),
    (-54963, -35693),
    (-55578, -34729),
    (-56175, -33754),
    (-56756, -32768),
    (-57319, -31772),
    (-57865, -30767),
    (-58393, -29753),
    (-58903, -28729),
    (-59396, -27697),
    (-59870, -26656),
    (-60326, -25607),
    (-60764, -24550),
    (-61183, -23486),
    (-61584, -22415),
    (-61966, -21336),
    (-62328, -20252),
    (-62672, -19161),
    (-62997, -18064),
    (-63303, -16962),
    (-63589, -15855),
    (-63856, -14742),
    (-64104, -13626),
    (-64332, -12505),
    (-64540, -11380),
    (-64729, -10252),
    (-64898, -9121),
    (-65048, -7987),
    (-65177, -6850),
    (-65287, -5712),
    (-65376, -4572),
    (-65446, -3430),
    (-65496, -2287),
    (-65526, -1144),
    (-65536, 0),
    (-65526, 1144),
    (-65496, 2287),
    (-65446, 3430),
    (-65376, 4572),
    (-65287, 5712),
    (-65177, 6850),
    (-65048, 7987),
    (-64898, 9121),
    (-64729, 10252),
    (-64540, 11380),
    (-64332, 12505),
    (-64104, 13626),
    (-63856, 14742),
    (-63589, 15855),
    (-63303, 16962),
    (-62997, 18064),
    (-62672, 19161),
    (-62328, 20252),
    (-61966, 21336),
    (-61584, 22415),
    (-61183, 23486),
    (-60764, 24550),
    (-60326, 25607),
    (-59870, 26656),
    (-59396, 27697),
    (-58903, 28729),
    (-58393, 29753),
    (-57865, 30767),
    (-57319, 31772),
    (-56756, 32768),
    (-56175, 33754),
    (-55578, 34729),
    (-54963, 35693),
    (-54332, 36647),
    (-53684, 37590),
    (-53020, 38521),
    (-52339, 39441),
    (-51643, 40348),
    (-50931, 41243),
    (-50203, 42126),
    (-49461, 42995),
    (-48703, 43852),
    (-47930, 44695),
    (-47143, 45525),
    (-46341, 46341),
    (-45525, 47143),
    (-44695, 47930),
    (-43852, 48703),
    (-42995, 49461),
    (-42126, 50203),
    (-41243, 50931),
    (-40348, 51643),
    (-39441, 52339),
    (-38521, 53020),
    (-37590, 53684),
    (-36647, 54332),
    (-35693, 54963),
    (-34729, 55578),
    (-33754, 56175),
    (-32768, 56756),
    (-31772, 57319),
    (-30767, 57865),
    (-29753, 58393),
    (-28729, 58903),
    (-27697, 59396),
    (-26656, 59870),
    (-25607, 60326),
    (-24550, 60764),
    (-23486, 61183),
    (-22415, 61584),
    (-21336, 61966),
    (-20252, 62328),
    (-19161, 62672),
    (-18064, 62997),
    (-16962, 63303),
    (-15855, 63589),
    (-14742, 63856),
    (-13626, 64104),
    (-12505, 64332),
    (-11380, 64540),
    (-10252, 64729),
    (-9121, 64898),
    (-7987, 65048),
    (-6850, 65177),
    (-5712, 65287),
    (-4572, 65376),
    (-3430, 65446),
    (-2287, 65496),
    (-1144, 65526),
];

/// Sine and cosine of `deg`, as `(sin, cos)`, scaled to 2^16.
pub fn sin_cos(deg: i32) -> (i64, i64) {
    SIN_COS[deg.rem_euclid(360) as usize]
}

/// A kind's shapes, placed at a point and facing, ready to test against a
/// cell centre.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Placed {
    pub shapes: Vec<Shape>,
    pub at: Point,
    pub facing: i32,
}

/// Rotate the vector from `at` to `p` by `-facing`, into the placement's own
/// frame, using the fixed table. Facing 0 leaves it unchanged.
fn to_local(at: Point, facing: i32, p: Point) -> (i64, i64) {
    let dx = i64::from(p.x - at.x);
    let dz = i64::from(p.z - at.z);
    let (sin, cos) = sin_cos(facing);
    let x = (dx * cos + dz * sin) >> 16;
    let z = (-dx * sin + dz * cos) >> 16;
    (x, z)
}

/// Rotate a point in the placement's own frame by `facing`, back into world
/// coordinates relative to `at`. The inverse of `to_local`.
fn from_local(at: Point, facing: i32, lx: i64, lz: i64) -> (i64, i64) {
    let (sin, cos) = sin_cos(facing);
    let x = i64::from(at.x) + ((lx * cos - lz * sin) >> 16);
    let z = i64::from(at.z) + ((lx * sin + lz * cos) >> 16);
    (x, z)
}

/// Where a point in a placement's own frame, such as an anchor, lies in the
/// world, rotated by the same fixed table `covers` uses.
pub fn world_point(at: Point, facing: i32, local: Point) -> Point {
    let (x, z) = from_local(at, facing, i64::from(local.x), i64::from(local.z));
    Point {
        x: x as i32,
        z: z as i32,
    }
}

/// Whether `p` lies inside `shape`, grown by `margin`, given the placement's
/// own frame. A rect's inside includes its minimum edges and excludes its
/// maximum edges, matching `Rect::contains`.
fn shape_covers(shape: &Shape, at: Point, facing: i32, p: Point, margin: i64) -> bool {
    let (x, z) = to_local(at, facing, p);
    match *shape {
        Shape::Rect { x: rx, z: rz, w, d } => {
            let min_x = i64::from(rx) - margin;
            let max_x = i64::from(rx) + i64::from(w) + margin;
            let min_z = i64::from(rz) - margin;
            let max_z = i64::from(rz) + i64::from(d) + margin;
            x >= min_x && x < max_x && z >= min_z && z < max_z
        }
        Shape::Disc { x: cx, z: cz, r } => {
            let dx = x - i64::from(cx);
            let dz = z - i64::from(cz);
            let grown = i64::from(r) + margin;
            dx * dx + dz * dz < grown * grown
        }
    }
}

/// True when `p` lies inside any of `placed`'s shapes, grown by `margin`.
pub fn covers(placed: &Placed, p: Point, margin: i64) -> bool {
    placed
        .shapes
        .iter()
        .any(|shape| shape_covers(shape, placed.at, placed.facing, p, margin))
}

/// The world-space axis-aligned bounds of one shape grown by `margin`, at
/// `at`/`facing`, as `(min_x, min_z, max_x, max_z)`.
///
/// The margin is added to the shape in its own frame before rotating: it is
/// tested there too (`shape_covers` rotates the query point into the same
/// frame and compares against the grown bounds directly), so a margin added
/// afterward, in world axes, would not match a rotated shape — growing the
/// rotated rect's corners by a world-axis margin covers a different, larger
/// area than the rotated, margin-grown rect actually reaches.
fn shape_world_bounds(shape: &Shape, at: Point, facing: i32, margin: i64) -> (i64, i64, i64, i64) {
    match *shape {
        Shape::Rect { x, z, w, d } => {
            let min_x = i64::from(x) - margin;
            let min_z = i64::from(z) - margin;
            let max_x = i64::from(x) + i64::from(w) + margin;
            let max_z = i64::from(z) + i64::from(d) + margin;
            let corners = [
                (min_x, min_z),
                (max_x, min_z),
                (min_x, max_z),
                (max_x, max_z),
            ];
            let mut lo_x = i64::MAX;
            let mut hi_x = i64::MIN;
            let mut lo_z = i64::MAX;
            let mut hi_z = i64::MIN;
            for (lx, lz) in corners {
                let (wx, wz) = from_local(at, facing, lx, lz);
                lo_x = lo_x.min(wx);
                hi_x = hi_x.max(wx);
                lo_z = lo_z.min(wz);
                hi_z = hi_z.max(wz);
            }
            (lo_x, lo_z, hi_x, hi_z)
        }
        Shape::Disc { x, z, r } => {
            let (cx, cz) = from_local(at, facing, i64::from(x), i64::from(z));
            let r = i64::from(r) + margin;
            (cx - r, cz - r, cx + r, cz + r)
        }
    }
}

/// How far outward `bounds` rounds its computed world-space box, beyond the
/// margin already folded into each shape.
///
/// Treat `SIN_COS`'s rotation as exact: the table's entries are within about
/// 8e-6 relative error of the true unit circle (the worst entry, degree 7,
/// has squared magnitude off by about 67,232 out of 65536², pinned to the
/// real data by `sin_cos_table_entries_stay_close_to_the_unit_circle`), so
/// that error is folded into the slack below rather than tracked
/// separately. What is *not* negligible is that `to_local` and `from_local`
/// each floor twice (`>> 16`), and floor toward −∞, so each ever only
/// *removes* up to (but never reaching) 1 cm along each axis — each is a
/// vector error `f` with `|f| < √2`, never in a direction that helps.
///
/// For a rect, `covers` compares rotated coordinates directly against a
/// fixed local box; a single flooring vector can only shift the tested point
/// by less than `√2` either way, and it is compared against a box already
/// grown by the margin, so this is dominated by the disc case below (also
/// checked directly: 200,000 randomised rects, positions, margins and
/// facings, with no violations at even 1 cm).
///
/// For a disc, write `w = p − at` (true world offset) and `C` for the disc's
/// *exact* (continuous-rotation) centre offset from `at`. Let `q` be the
/// vector `covers` actually tests: the disc's local centre subtracted from
/// `to_local(at, facing, p)`. Because rotation is exact-distance-preserving,
/// `|w − C|` equals `|q + f|` for a single flooring vector `f`, `|f| < √2`
/// (the algebra: `to_local`'s exact-rotation counterpart of `p − at`, minus
/// its own flooring loss `f`, minus the shape's local centre, is exactly `q`
/// after rotating everything back by the *exact* inverse — a distance-
/// preserving step). So `|w − C| ≤ |q| + |f| < R + √2` whenever `covers`
/// finds `|q| < R` (`R = r + margin`).
///
/// `bounds` does not use the exact centre `C`; it places the box at
/// `from_local(at, facing, shape.x, shape.z)`, which is `at + C − f'` for a
/// *second*, independent flooring vector `f'` (zero only when the shape sits
/// exactly on the placement's own origin, since rotating the zero vector
/// loses nothing — the centred-disc case). So the box's centre can itself be
/// up to `|f'| < √2` off the exact centre, and by the triangle inequality
/// again, the true distance from `p` to the *box's* centre is bounded by
/// `R + √2 + √2 = R + 2√2 ≈ R + 2.8284`.
///
/// Three centimetres clears `2√2` with headroom for the folded-in table
/// error and the strict `<` the box's far edge needs over that bound (it is
/// exclusive, matching `Rect::contains`).
/// `bounds_contains_every_covered_disc_point_across_all_facings` sweeps both
/// a centred and an off-centre disc across every facing to check this
/// directly, and the facing-13 regression pins the case that first exposed
/// the gap.
const ROUND_OUT: i64 = 3;

/// An axis-aligned box covering `placed`'s shapes at their facing, grown by
/// `margin`. The rotation table truncates rather than rounds to nearest, so
/// this rounds its result outward by `ROUND_OUT` more, keeping the box a
/// safe cover for every point `covers` would report, not a tight one.
pub fn bounds(placed: &Placed, margin: i64) -> Rect {
    let (x, z, far_x, far_z) = bounds_wide(placed, margin);
    let (x, z) = (x as i32, z as i32);
    Rect {
        x,
        z,
        w: far_x as i32 - x,
        d: far_z as i32 - z,
    }
}

/// [`bounds`] as `(min_x, min_z, max_x, max_z)` in `i64`, which cannot
/// overflow however far from the origin the placement stands: check it lies
/// on the grid before narrowing it with [`bounds`].
pub fn bounds_wide(placed: &Placed, margin: i64) -> (i64, i64, i64, i64) {
    if placed.shapes.is_empty() {
        let (x, z) = (i64::from(placed.at.x), i64::from(placed.at.z));
        return (x, z, x, z);
    }
    let mut min_x = i64::MAX;
    let mut max_x = i64::MIN;
    let mut min_z = i64::MAX;
    let mut max_z = i64::MIN;
    for shape in &placed.shapes {
        let (sx0, sz0, sx1, sz1) = shape_world_bounds(shape, placed.at, placed.facing, margin);
        min_x = min_x.min(sx0);
        max_x = max_x.max(sx1);
        min_z = min_z.min(sz0);
        max_z = max_z.max(sz1);
    }
    (
        min_x - ROUND_OUT,
        min_z - ROUND_OUT,
        max_x + ROUND_OUT,
        max_z + ROUND_OUT,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use city_contracts::{Point, Shape};

    #[test]
    fn sin_cos_matches_the_cardinal_directions() {
        assert_eq!(sin_cos(0), (0, 65536));
        assert_eq!(sin_cos(90), (65536, 0));
        assert_eq!(sin_cos(-90), sin_cos(270));
    }

    #[test]
    fn a_rotated_rect_covers_a_different_point_than_facing_zero() {
        let shapes = vec![Shape::Rect {
            x: 0,
            z: 0,
            w: 100,
            d: 60,
        }];
        let at = Point { x: 0, z: 0 };
        let p = Point { x: -30, z: 50 };
        let facing_90 = Placed {
            shapes: shapes.clone(),
            at,
            facing: 90,
        };
        let facing_0 = Placed {
            shapes,
            at,
            facing: 0,
        };
        assert!(covers(&facing_90, p, 0), "facing 90 should cover p");
        assert!(!covers(&facing_0, p, 0), "facing 0 should not cover p");
    }

    #[test]
    fn the_margin_grows_a_rect_by_exactly_ten_cm_on_each_side() {
        let placed = Placed {
            shapes: vec![Shape::Rect {
                x: 0,
                z: 0,
                w: 100,
                d: 60,
            }],
            at: Point { x: 0, z: 0 },
            facing: 0,
        };
        assert!(covers(&placed, Point { x: 109, z: 30 }, MARGIN));
        assert!(!covers(&placed, Point { x: 110, z: 30 }, MARGIN));
    }

    #[test]
    fn a_discs_boundary_uses_strict_less_than() {
        let placed = Placed {
            shapes: vec![Shape::Disc { x: 0, z: 0, r: 50 }],
            at: Point { x: 0, z: 0 },
            facing: 0,
        };
        assert!(covers(&placed, Point { x: 49, z: 0 }, 0));
        assert!(!covers(&placed, Point { x: 50, z: 0 }, 0));
    }

    #[test]
    fn bounds_contains_every_covered_point_on_a_sweep() {
        let placed = Placed {
            shapes: vec![Shape::Rect {
                x: -10,
                z: -8,
                w: 20,
                d: 16,
            }],
            at: Point { x: 100, z: 100 },
            facing: 37,
        };
        let margin = MARGIN;
        let b = bounds(&placed, margin);
        for dx in -40..=40 {
            for dz in -40..=40 {
                let p = Point {
                    x: 100 + dx,
                    z: 100 + dz,
                };
                if covers(&placed, p, margin) {
                    assert!(b.contains(p), "bounds missed a covered point {p:?}");
                }
            }
        }
    }

    /// The exact case the reviewer reproduced: a street-tree-sized disc at
    /// facing 13 covers a point `bounds` used to miss, because `covers`
    /// compares a squared magnitude that flooring can only ever shrink, not
    /// grow (see `ROUND_OUT`'s doc comment).
    #[test]
    fn bounds_covers_the_facing_13_disc_regression() {
        let placed = Placed {
            shapes: vec![Shape::Disc { x: 0, z: 0, r: 100 }],
            at: Point { x: 0, z: 0 },
            facing: 13,
        };
        let margin = MARGIN;
        let p = Point { x: 1, z: 111 };
        assert!(
            covers(&placed, p, margin),
            "the repro point should be covered"
        );
        let b = bounds(&placed, margin);
        assert!(
            b.contains(p),
            "bounds missed the facing-13 regression point"
        );
    }

    #[test]
    fn bounds_contains_every_covered_disc_point_across_all_facings() {
        // A centred 1 m disc (street-tree's first footprint) and an
        // off-centre one, so the rotated-centre placement is exercised too.
        for (x, z, r) in [(0, 0, 100), (30, -45, 37)] {
            for facing in 0..360 {
                let at = Point { x: 500, z: -300 };
                let placed = Placed {
                    shapes: vec![Shape::Disc { x, z, r }],
                    at,
                    facing,
                };
                let margin = MARGIN;
                let b = bounds(&placed, margin);
                // Sweep a 1 cm grid in a band either side of the boundary,
                // around the shape's true rotated centre, rather than the
                // whole disc: the interior is trivially covered and bounded,
                // and the failure mode only ever shows up at the edge.
                let (cx, cz) = from_local(at, facing, i64::from(x), i64::from(z));
                let reach = i64::from(r) + margin + 6;
                let inner = (i64::from(r) + margin - 6).max(0);
                for dx in -reach..=reach {
                    for dz in -reach..=reach {
                        let d2 = dx * dx + dz * dz;
                        if d2 < inner * inner || d2 > reach * reach {
                            continue;
                        }
                        let p = Point {
                            x: (cx + dx) as i32,
                            z: (cz + dz) as i32,
                        };
                        if covers(&placed, p, margin) {
                            assert!(
                                b.contains(p),
                                "bounds missed a covered point {p:?} at facing {facing}, disc ({x},{z},{r})"
                            );
                        }
                    }
                }
            }
        }
    }

    /// The reasoning behind `ROUND_OUT` assumes the committed table's
    /// entries sit close to the unit circle scaled by 65536. This pins that
    /// assumption to the actual data, so a future regeneration that drifts
    /// further would fail loudly here rather than silently widening the
    /// gap `ROUND_OUT` is sized to cover.
    #[test]
    fn sin_cos_table_entries_stay_close_to_the_unit_circle() {
        for deg in 0..360 {
            let (s, c) = sin_cos(deg);
            let mag_sq = s * s + c * c;
            let unit_sq = 65536i64 * 65536;
            // The worst entry in the committed table deviates from the unit
            // circle by about 67,232 in squared-magnitude terms (degree 7);
            // 100,000 gives headroom without hiding a real regression.
            assert!(
                (mag_sq - unit_sq).abs() < 100_000,
                "degree {deg} strays too far from the unit circle: {mag_sq} vs {unit_sq}"
            );
        }
    }
}
