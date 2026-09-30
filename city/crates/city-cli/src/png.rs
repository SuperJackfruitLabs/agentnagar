//! A minimal PNG encoder for `grid --png`: one pixel per grid cell, RGB8,
//! stored (uncompressed) deflate blocks. No image dependency exists in this
//! workspace's lockfile, so this writes the format directly rather than add
//! one for a single diagnostic picture.

use city_core::nav::{Cell, NavGrid};
use std::collections::BTreeSet;

/// Walkable floor.
pub const WHITE: [u8; 3] = [255, 255, 255];
/// A door span (always walkable).
pub const GREEN: [u8; 3] = [0, 170, 0];
/// A seat's own cell (always walkable).
pub const BLUE: [u8; 3] = [0, 90, 220];
/// A cell a placement's footprint blocks.
pub const RED: [u8; 3] = [200, 0, 0];
/// A blocked cell whose floor belongs to a room, but not under any
/// placement's footprint: a building shell's wall, standing over ground
/// that would otherwise be a room's floor.
pub const TINT: [u8; 3] = [190, 190, 200];
/// Outside every room: never walkable, never floor.
pub const BLACK: [u8; 3] = [0, 0, 0];

/// One cell's colour: a door span first (always walkable), then a seat's
/// own cell (always walkable), then plain walkable floor, then a cell a
/// placement's footprint blocks, then a room's floor blocked some other
/// way (a shell wall), then background.
fn classify(grid: &NavGrid, blocked: &BTreeSet<Cell>, c: Cell) -> [u8; 3] {
    if grid.in_door_span(c) {
        GREEN
    } else if grid.is_seat_cell(c) {
        BLUE
    } else if grid.walkable(c) {
        WHITE
    } else if blocked.contains(&c) {
        RED
    } else if grid.floor_room_at(c).is_some() {
        TINT
    } else {
        BLACK
    }
}

/// Renders `grid` as a 1 px-per-cell RGB8 PNG, `cols` wide and `rows` deep.
/// `blocked` names the cells a placement's footprint blocks (drawn red);
/// every other non-walkable, in-room cell is drawn as a blocked room (a
/// shell wall).
pub fn render(grid: &NavGrid, blocked: &BTreeSet<Cell>, cols: i32, rows: i32) -> Vec<u8> {
    let (cols_u, rows_u) = (cols.max(0) as usize, rows.max(0) as usize);
    let mut pixels = vec![0u8; cols_u * rows_u * 3];
    for j in 0..rows {
        for i in 0..cols {
            let colour = classify(grid, blocked, Cell { i, j });
            let at = ((j as usize) * cols_u + i as usize) * 3;
            pixels[at..at + 3].copy_from_slice(&colour);
        }
    }
    encode_rgb8(cols_u as u32, rows_u as u32, &pixels)
}

// ---- PNG encoding: signature, IHDR, one IDAT (zlib, stored blocks), IEND ----

fn crc32(data: &[u8]) -> u32 {
    fn table() -> &'static [u32; 256] {
        static TABLE: std::sync::OnceLock<[u32; 256]> = std::sync::OnceLock::new();
        TABLE.get_or_init(|| {
            let mut t = [0u32; 256];
            for (n, slot) in t.iter_mut().enumerate() {
                let mut c = n as u32;
                for _ in 0..8 {
                    c = if c & 1 != 0 {
                        0xEDB8_8320 ^ (c >> 1)
                    } else {
                        c >> 1
                    };
                }
                *slot = c;
            }
            t
        })
    }
    let table = table();
    let mut c = 0xFFFF_FFFFu32;
    for &b in data {
        c = table[((c ^ u32::from(b)) & 0xFF) as usize] ^ (c >> 8);
    }
    c ^ 0xFFFF_FFFF
}

fn adler32(data: &[u8]) -> u32 {
    const MODULO: u32 = 65521;
    let (mut a, mut b) = (1u32, 0u32);
    for &byte in data {
        a = (a + u32::from(byte)) % MODULO;
        b = (b + a) % MODULO;
    }
    (b << 16) | a
}

fn push_chunk(out: &mut Vec<u8>, kind: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    let mut body = Vec::with_capacity(4 + data.len());
    body.extend_from_slice(kind);
    body.extend_from_slice(data);
    out.extend_from_slice(&body);
    out.extend_from_slice(&crc32(&body).to_be_bytes());
}

/// The most bytes one deflate "stored" block may carry.
const MAX_STORED_BLOCK: usize = 65_535;

/// Wraps `raw` in a zlib stream of stored (uncompressed) deflate blocks: a
/// valid, if uncompressed, IDAT payload, with no compression library.
fn zlib_stored(raw: &[u8]) -> Vec<u8> {
    let mut z = Vec::with_capacity(raw.len() + raw.len() / MAX_STORED_BLOCK.max(1) * 5 + 16);
    // CMF/FLG for a 32k window, no preset dictionary; the pair's value must
    // be a multiple of 31, which 0x78 0x01 is.
    z.push(0x78);
    z.push(0x01);
    let mut i = 0;
    loop {
        let end = (i + MAX_STORED_BLOCK).min(raw.len());
        let is_last = end == raw.len();
        z.push(u8::from(is_last));
        let len = (end - i) as u16;
        z.extend_from_slice(&len.to_le_bytes());
        z.extend_from_slice(&(!len).to_le_bytes());
        z.extend_from_slice(&raw[i..end]);
        i = end;
        if is_last {
            break;
        }
    }
    z.extend_from_slice(&adler32(raw).to_be_bytes());
    z
}

/// Encodes `width` × `height` RGB8 pixels (`width * height * 3` bytes, row
/// major) as a PNG.
pub fn encode_rgb8(width: u32, height: u32, pixels: &[u8]) -> Vec<u8> {
    assert_eq!(
        pixels.len(),
        width as usize * height as usize * 3,
        "pixels must be width*height*3 bytes"
    );
    let mut out = Vec::new();
    out.extend_from_slice(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]);

    let mut ihdr = Vec::with_capacity(13);
    ihdr.extend_from_slice(&width.to_be_bytes());
    ihdr.extend_from_slice(&height.to_be_bytes());
    ihdr.extend_from_slice(&[8, 2, 0, 0, 0]); // 8-bit depth, RGB, defaults
    push_chunk(&mut out, b"IHDR", &ihdr);

    let stride = width as usize * 3;
    let mut raw = Vec::with_capacity((stride + 1) * height as usize);
    for row in pixels.chunks(stride) {
        raw.push(0); // filter type 0: None
        raw.extend_from_slice(row);
    }
    push_chunk(&mut out, b"IDAT", &zlib_stored(&raw));
    push_chunk(&mut out, b"IEND", &[]);
    out
}

/// Undoes [`encode_rgb8`], reading back exactly the stored-block zlib
/// stream this module writes: enough to prove the encoder round-trips,
/// without a general PNG decoder. `pub` so tests of `grid --png`'s real
/// output, in the CLI's own integration tests, can decode it the same way.
///
/// Returns the width, height and the RGB8 pixels, row major, un-filtered
/// (every row this encoder writes is filter type 0, None).
pub fn decode_rgb8(png: &[u8]) -> (u32, u32, Vec<u8>) {
    assert_eq!(
        &png[0..8],
        &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]
    );
    let mut pos = 8;
    let (mut width, mut height) = (0u32, 0u32);
    let mut idat = Vec::new();
    loop {
        let len = u32::from_be_bytes(png[pos..pos + 4].try_into().unwrap()) as usize;
        let kind = &png[pos + 4..pos + 8];
        let data = &png[pos + 8..pos + 8 + len];
        match kind {
            b"IHDR" => {
                width = u32::from_be_bytes(data[0..4].try_into().unwrap());
                height = u32::from_be_bytes(data[4..8].try_into().unwrap());
            }
            b"IDAT" => idat.extend_from_slice(data),
            b"IEND" => break,
            _ => {}
        }
        pos += 8 + len + 4;
    }
    // Skip the zlib header, walk stored blocks, drop the adler32 trailer.
    let mut raw = Vec::new();
    let mut i = 2;
    loop {
        let is_last = idat[i] & 1 != 0;
        let len = u16::from_le_bytes(idat[i + 1..i + 3].try_into().unwrap()) as usize;
        raw.extend_from_slice(&idat[i + 5..i + 5 + len]);
        i += 5 + len;
        if is_last {
            break;
        }
    }
    let stride = width as usize * 3;
    let mut pixels = Vec::with_capacity(width as usize * height as usize * 3);
    for row in raw.chunks(stride + 1) {
        assert_eq!(row[0], 0, "every row is filter type None");
        pixels.extend_from_slice(&row[1..]);
    }
    (width, height, pixels)
}

/// One decoded image's pixel at cell `(i, j)`, for a test's assertions.
pub fn pixel_at(width: u32, pixels: &[u8], i: i32, j: i32) -> [u8; 3] {
    let at = (j as usize * width as usize + i as usize) * 3;
    pixels[at..at + 3].try_into().expect("3 bytes per pixel")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_a_small_image() {
        let pixels = [
            WHITE.as_slice(),
            RED.as_slice(),
            GREEN.as_slice(),
            BLUE.as_slice(),
        ]
        .concat();
        let png = encode_rgb8(2, 2, &pixels);
        let (w, h, back) = decode_rgb8(&png);
        assert_eq!((w, h), (2, 2));
        assert_eq!(back, pixels);
    }

    #[test]
    fn round_trips_a_row_that_crosses_one_stored_block() {
        // A row of white pixels long enough that its raw scanline data
        // spans more than one 65,535-byte stored block.
        let width = 25_000u32;
        let pixels = WHITE.repeat(width as usize);
        let png = encode_rgb8(width, 1, &pixels);
        let (w, h, back) = decode_rgb8(&png);
        assert_eq!((w, h), (width, 1));
        assert_eq!(back, pixels);
    }
}
