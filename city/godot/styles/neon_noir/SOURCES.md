# Sources

This file records the interface skin's assets. The pack's scene assets are built by its tools under `city/tools/styles/`.

## Interface fonts

Downloaded on 2026-09-26 from [google/fonts](https://github.com/google/fonts), pinned to the last commit that touched each family's folder. Each is licensed under the SIL Open Font License 1.1; the licence travels beside the font.

| File | Family (designer) | Use | Version | Source | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/Rajdhani-Bold.ttf` | Rajdhani (Indian Type Foundry) | display (Bold) | Version 1.201 | [`ofl/rajdhani/Rajdhani-Bold.ttf`](https://raw.githubusercontent.com/google/fonts/8772f86137e17678cbd3584ca9a3c9486c3e7e50/ofl/rajdhani/Rajdhani-Bold.ttf) | `691470dd3286a14e9677940d0bf75796179841ba5215cbda1a2c8910a3226afd` |
| `assets/fonts/Rajdhani-Medium.ttf` | Rajdhani (Indian Type Foundry) | body (Medium) | Version 1.201 | [`ofl/rajdhani/Rajdhani-Medium.ttf`](https://raw.githubusercontent.com/google/fonts/8772f86137e17678cbd3584ca9a3c9486c3e7e50/ofl/rajdhani/Rajdhani-Medium.ttf) | `12ff7dcfe4c206e3875ac53b1762eab57de6a2fa7f5a86c26b97b88d6591eac2` |

- `assets/fonts/Rajdhani-OFL.txt`: [`ofl/rajdhani/OFL.txt`](https://raw.githubusercontent.com/google/fonts/8772f86137e17678cbd3584ca9a3c9486c3e7e50/ofl/rajdhani/OFL.txt), unchanged.
- google/fonts commit for Rajdhani: `8772f86137e17678cbd3584ca9a3c9486c3e7e50`.

## Interface skin

The `ui` block in `style.json` follows sheet 03 r004: dark navy glass (`#0E1A2E` at 92% alpha), cyan-edged buttons (1 px `panel_edge` border) and the `glow` focus, a soft halo drawn by `core/ui/focus_glow.gdshader`. Every value is the plan's; nothing needed adjusting for contrast.
