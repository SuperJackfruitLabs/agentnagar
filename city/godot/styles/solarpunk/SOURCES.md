# Sources

This file records the interface skin's assets. The pack's scene assets are built by its tools under `city/tools/styles/`.

## Interface fonts

Downloaded on 2026-09-26 from [google/fonts](https://github.com/google/fonts), pinned to the last commit that touched each family's folder. Each is licensed under the SIL Open Font License 1.1; the licence travels beside the font.

| File | Family (designer) | Use | Version | Source | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/JosefinSans-Variable.ttf` | Josefin Sans (Santiago Orozco) | variable, wght 100-700 | Version 2.001 | [`ofl/josefinsans/JosefinSans[wght].ttf`](https://raw.githubusercontent.com/google/fonts/0fd277cf519ed2c02e63e4e19220f4cf6103df51/ofl/josefinsans/JosefinSans%5Bwght%5D.ttf) | `9255abdb5f393bc51e101abbd07a716a977fd3e15472b1b84b260f426a342bfd` |

- `assets/fonts/JosefinSans-OFL.txt`: [`ofl/josefinsans/OFL.txt`](https://raw.githubusercontent.com/google/fonts/0fd277cf519ed2c02e63e4e19220f4cf6103df51/ofl/josefinsans/OFL.txt), unchanged.
- google/fonts commit for Josefin Sans: `0fd277cf519ed2c02e63e4e19220f4cf6103df51`.

`JosefinSans-Bold.tres` (display) and `JosefinSans-Regular.tres` (body) are `FontVariation`s of the variable file at wght 700 and 400.

## Interface skin

The `ui` block in `style.json` follows sheet 03 r003: a deep-teal panel in a brass frame, with cream rounded buttons lettered in teal.

`assets/ui/brass_frame.png` (96 x 96, nine-slice margin 16) is drawn by `city/tools/styles/shared/ui_frames.py` and checked by `test_ui_frames.py`: a 12 px brass bevel (`#B8862F` at its edges to `#E4C27A` along its middle) round a `#123C3A` field, with rounded outer corners. SHA-256 `b24214e181aaff37f297e1d8ee8a2bc9597dc5a6ba14b3d762024e0198f9fcc2`.

Contrast change (2026-09-26). The plan gave panel `#F3EEDF` with ink `#123C3A`, and accent `#1F6F68` with white. But the panel is the brass frame, whose field is `#123C3A`: text drawn on it in `#123C3A` measured 1:1 and the title's name disappeared, and the plan's brass focus ring measured 2.8:1 on the cream it was checked against. The colours now describe the surface the text sits on: panel `#123C3A` (the frame's field) with ink `#F3EEDF` (10.4:1); accent `#F3EEDF` with accent ink `#123C3A` (10.4:1), the cream buttons of the facility panel; focus ring `#B8862F` as planned, 3.7:1 on the teal. `#1F6F68` is no longer used.
