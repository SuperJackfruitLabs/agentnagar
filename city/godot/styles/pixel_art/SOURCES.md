# Sources

This file records the interface skin's assets. The pack's scene assets are built by its tools under `city/tools/styles/`.

## Interface fonts

Downloaded on 2026-09-26 from [google/fonts](https://github.com/google/fonts), pinned to the last commit that touched each family's folder. Each is licensed under the SIL Open Font License 1.1; the licence travels beside the font.

| File | Family (designer) | Use | Version | Source | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/PressStart2P-Regular.ttf` | Press Start 2P (CodeMan38) | display | Version 3.000 | [`ofl/pressstart2p/PressStart2P-Regular.ttf`](https://raw.githubusercontent.com/google/fonts/e06fe11c39051bddaef73ec338a9d1c8175723f1/ofl/pressstart2p/PressStart2P-Regular.ttf) | `034c77f1f05ec89421e4a63f0e3a4ca1ecf852cc6d2bf611f126f275728e017d` |
| `assets/fonts/PixelifySans-Variable.ttf` | Pixelify Sans (Stefie Justprince) | body; variable, wght 400-700, used at its default 400 | Version 1.000 | [`ofl/pixelifysans/PixelifySans[wght].ttf`](https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf) | `9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5` |

- `assets/fonts/PressStart2P-OFL.txt`: [`ofl/pressstart2p/OFL.txt`](https://raw.githubusercontent.com/google/fonts/e06fe11c39051bddaef73ec338a9d1c8175723f1/ofl/pressstart2p/OFL.txt), unchanged.
- google/fonts commit for Press Start 2P: `e06fe11c39051bddaef73ec338a9d1c8175723f1`.
- `assets/fonts/PixelifySans-OFL.txt`: [`ofl/pixelifysans/OFL.txt`](https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/pixelifysans/OFL.txt), unchanged.
- google/fonts commit for Pixelify Sans: `8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5`.

Both pixel faces are imported without antialiasing, hinting or subpixel positioning (see their `.import` files), and the skin sets `pixel_font`, so each face is drawn only at whole multiples of its own grid: Press Start 2P at `pixel_base` (8 px, one pixel is an eighth of its em), Pixelify Sans at `pixel_base_body` (10 px, one pixel is about a tenth of its em).

## Interface skin

The `ui` block in `style.json` follows sheet 03 r008: dark navy pixel frames, blue-lit buttons (a frame button is tinted towards the accent on hover and press), pixel type and the `glow` focus.

`assets/ui/pixel_frame.png` (48 x 48 at one image pixel per screen pixel, nine-slice margin 6) is drawn by `city/tools/styles/shared/ui_frames.py` and checked by `test_ui_frames.py`: a 3 px `#0A0F22` outline, a 1 px `#3E5AA8` highlight and the `#141B33` field, with the corner pixels notched out. It is drawn with nearest filtering (the project's canvas default). It lies outside the sprite kit, so the kit's palette and reproducibility checks skip `assets/ui/`. SHA-256 `3c2735cdae4e6b29357be85e8e528319e60f59faeb0d076e6332f889d2a2f141`.

Every colour is the plan's; nothing needed adjusting for contrast.
