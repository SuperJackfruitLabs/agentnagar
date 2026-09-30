# Sources

This file records the interface skin's assets. The pack's scene assets are built by its tools under `city/tools/styles/`.

## Interface fonts

Downloaded on 2026-09-26 from [google/fonts](https://github.com/google/fonts), pinned to the last commit that touched each family's folder. Each is licensed under the SIL Open Font License 1.1; the licence travels beside the font.

| File | Family (designer) | Use | Version | Source | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/Baloo2-Variable.ttf` | Baloo 2 (Ek Type) | variable, wght 400-800 | Version 1.700 | [`ofl/baloo2/Baloo2[wght].ttf`](https://raw.githubusercontent.com/google/fonts/c13390277dfb1fcc7415d84ef7ef9cfc1e52f8c1/ofl/baloo2/Baloo2%5Bwght%5D.ttf) | `d47a6852548059b1db49a1319d06d499d546c3fa2237cf9eee9c43c8abb025c2` |

- `assets/fonts/Baloo2-OFL.txt`: [`ofl/baloo2/OFL.txt`](https://raw.githubusercontent.com/google/fonts/c13390277dfb1fcc7415d84ef7ef9cfc1e52f8c1/ofl/baloo2/OFL.txt), unchanged.
- google/fonts commit for Baloo 2: `c13390277dfb1fcc7415d84ef7ef9cfc1e52f8c1`.

`Baloo2-ExtraBold.tres` (display) and `Baloo2-Medium.tres` (body) are `FontVariation`s of the variable file at wght 800 and 500.

## Interface skin

The `ui` block in `style.json` follows sheet 03 r004: cream panels and chunky rounded buttons in bold type.

Contrast change (the plan's ruling). White on the sheet's orange `#E57A1F` measures about 2.9:1, under the 4.5:1 floor, so the accent is `#B85A10` (white on it measures about 4.7:1). The brighter orange is kept for the panel's decorative edge only (`panel_edge`).
