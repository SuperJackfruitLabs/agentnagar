# Sources

This file records the interface skin's assets. The pack's scene assets are built by its tools under `city/tools/styles/`.

## Interface fonts

Downloaded on 2026-09-26 from [google/fonts](https://github.com/google/fonts), pinned to the last commit that touched each family's folder. Each is licensed under the SIL Open Font License 1.1; the licence travels beside the font.

| File | Family (designer) | Use | Version | Source | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/MPLUSRounded1c-ExtraBold.ttf` | M PLUS Rounded 1c (Coji Morishita, M+ Fonts Project) | display (ExtraBold), subset | Version 1.059.20150529 | [`ofl/mplusrounded1c/MPLUSRounded1c-ExtraBold.ttf`](https://raw.githubusercontent.com/google/fonts/84efd8ad78c3710ad14bd909e3bc407151885628/ofl/mplusrounded1c/MPLUSRounded1c-ExtraBold.ttf) | `2759f24feaf4bd5f8a72858506feca40b1640f5567cadde86eb747b0f124d995` |
| `assets/fonts/MPLUSRounded1c-Regular.ttf` | M PLUS Rounded 1c (Coji Morishita, M+ Fonts Project) | body (Regular), subset | Version 1.059.20150529 | [`ofl/mplusrounded1c/MPLUSRounded1c-Regular.ttf`](https://raw.githubusercontent.com/google/fonts/84efd8ad78c3710ad14bd909e3bc407151885628/ofl/mplusrounded1c/MPLUSRounded1c-Regular.ttf) | `40b5d76f251f37c62d10ecfd24909741ca1f93e45695bb4e7bc9667b2de93946` |

- `assets/fonts/MPLUSRounded1c-OFL.txt`: google/fonts ships no `OFL.txt` in `ofl/mplusrounded1c/`, so this is the standard OFL 1.1 text under the family's copyright line from its `METADATA.pb` ("Copyright 2016 The Rounded M+ Project Authors."); the fonts' own name tables carry the same OFL 1.1 notice.
- google/fonts commit for M PLUS Rounded 1c: `84efd8ad78c3710ad14bd909e3bc407151885628`.

Both files are subsets of the upstream fonts. The originals are 3.6 MB (ExtraBold, SHA-256 `8e7c15901dca87f1451b356dda594f7d092ba252a5dcc47da74523a242493c36`) and 3.4 MB (Regular, SHA-256 `b75708b53e45b06d17d470aeeca5b766e3d1b3999f03f13ec4eb863ca846c14c`), mostly Japanese glyphs the interface never draws. The subsets keep Latin, Latin-1, Latin Extended-A, and the punctuation, arrows and symbols the interface uses (`·`, `—`, `…`, `×`, `°`, `−`, `‹`, `›`), 704 characters in each. They were made with fontTools 4.66.0 (the SHA-256 values in the table are the subsets'):

```
U=U+0020-007E,U+00A0-00FF,U+0100-017F,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2200-22FF,U+2300-23FF,U+25A0-25FF,U+2600-26FF,U+2700-27BF
pyftsubset MPLUSRounded1c-ExtraBold.ttf --unicodes="$U" --layout-features='*' --output-file=MPLUSRounded1c-ExtraBold.ttf
pyftsubset MPLUSRounded1c-Regular.ttf --unicodes="$U" --layout-features='*' --output-file=MPLUSRounded1c-Regular.ttf
```

M PLUS Rounded 1c declares no Reserved Font Name, so the subsets keep the family's name, as the OFL allows.

## Interface skin

The `ui` block in `style.json` follows sheet 03 r004 (light rounded cards, blue buttons with white text, soft shadow). Every value is the plan's; nothing needed adjusting for contrast.
