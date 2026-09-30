# Audience, devices and accessibility for a global city

Desk research · 2026-09-18 · [Plan index](../README.md)

This brief collects the audience, device, network, platform-capability,
accessibility and localisation evidence that any later client choice must
satisfy. It follows [RD15](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18):
no engine, renderer or host is recommended here. Where a section names a
technology it is to state a fact about that technology, not to pick it. The
first slice it is written against is [RD01](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(walk the city, watch the 14 Guild agents at work), with public observation
only (RD03), registered interaction (RD04), comments, messages and assemblies
as core (RD05) and a global audience (RD11). It complements the
[platform brief](../architecture/PLATFORMS.md), which owns the candidate list.

**Evidence limits.** This is desk research. No device, browser build, engine
export or screen reader was tested for this brief. Market shares, speeds and
prices are as of the month stated in each row (mostly August 2026 for
StatCounter and Steam, December 2025 for Ookla-derived speeds), and they
move. Several figures were read through secondary pages because the primary
page could not be fetched; those rows say so. Any line marked *proposal* is a
suggestion for discussion, not a measured requirement. Legal notes are not
legal advice.

## What any client must satisfy (summary)

| Requirement | Evidence in this brief |
| --- | --- |
| Open from a link with nothing to install, on a phone | Browser-playable itch.io games convert views to plays about 3x better than download-only (S1); web share is half mobile worldwide, two-thirds in India (S2) |
| Fit a ~2 MB first payload and stay usable on a 6 GB Helio G99 phone over 9 Mbps | P75 baseline device and network (S3); median mobile page is already 2.3 MB (S4) |
| Not depend on WebGPU for the entrance | WebGPU is at ~87% global coverage but off by default in Firefox and only partial on macOS Safari; WebGL 2 is at ~96% (S5, S6) |
| Keep text (comments, messages, work state) in the DOM or an equivalent accessibility tree | Canvas text input, IME, Indic/Arabic shaping and screen readers all favour DOM text (S7–S10) |
| Offer a readable "text city" for every place and every agent's work state | WCAG 2.2 AA and the repo's own promise of readable equivalents (S11); engine screen-reader support does not yet reach the web (S12, S13) |
| Handle background tabs honestly | Timers throttle to once a minute after five hidden minutes; requestAnimationFrame stops (S14) |

## 1. Who shows up first, and where

### Likely first audiences

The first slice is a public spectacle: 14 named AI agents doing real work in
a walkable place. That draws people who already follow AI agents, before it
draws people who want a home. The table is an ordering argument, not a survey.

| Segment | Why they come first | What they need from the client | Evidence |
| --- | --- | --- | --- |
| Developers and AI-agent builders | Curious what agents "actually do all day"; want to read the work, not only see avatars | Fast link-open on desktop; readable work state; copyable links to a moment | Developer population: GitHub reports 180M+ developers, India added 5.2M in 2025 and is projected to pass the US by 2030 (S15); Stack Overflow respondents are 20% US, 9% Germany, 7% India, 6% UK (S16) |
| Indie makers and small studios | Compare their own practice; potential residents (RD09) | Low commitment; a way to come back (bookmark, PWA icon, notification) | itch.io benchmarks: median game gets 1,582 views; browser play converts 37% of views, downloads 6.9% (S1) |
| Students and learners | Free, observable, teachable | Phone-first; low data cost; text alternative for slow networks | India mobile share 64% of web traffic (S2); 1 GB costs about $0.16 in India versus $6.00 in the US (S17) |
| The curious public following AI agents | Shared links from social media; short visits | Instant load, no sign-in, embeds, something happening within seconds | Same conversion evidence as S1; ambient-use implications below |

Assumption to test: developer-oriented sites see more desktop traffic than
the general web. No public per-site figure was found for this brief. The
owner's own site analytics (section 6) is the cheapest way to check it.

### Where they are

| Measure | Worldwide | India | US | Source, month |
| --- | --- | --- | --- | --- |
| Web traffic by platform | Mobile 49.4%, desktop 49.1%, tablet 1.5% | Mobile 64.5%, desktop 35.0% | not fetched | StatCounter, Aug 2026 (S2) |
| Mobile OS | Android 67.6%, iOS 32.4% | Android 92.8%, iOS 7.2% | iOS 60.7%, Android 39.3% | StatCounter, Aug 2026 (S18) |
| Desktop OS | Windows 62.7%, macOS+OS X ~26.9%, Linux 8.9%, ChromeOS 1.5% | not fetched | not fetched | StatCounter, Aug 2026 (S19) |
| Browser, all platforms | Chrome 69.4%, Safari 15.8%, Edge 5.4%, Firefox 3.0%, Samsung Internet 2.0% | not fetched | not fetched | StatCounter, Aug 2026 (S20) |

Two readings matter. First, "global" is not one device profile: an iPhone
is the majority phone in the US and a 7% minority in India. Second, Safari's
16% share (all platforms) is mostly iOS, so any web client that fails on iOS
Safari loses most of the US phone audience even though it loses little of
India's.

### Install a client, or click a link?

| Comparable | Finding | Source |
| --- | --- | --- |
| itch.io (indie games) | Browser-playable: 37% of views become plays (median); download-only: 6.9%. "Basically 3x more people will play your game if it is" playable in the browser. | howtomarketagame.com benchmark, May 2025 (S1) |
| Steam as a discovery channel | $100 Steam Direct fee per app, recouped only after $1,000 adjusted gross revenue; more than 40% of the 12,732 games released in 2025 by the time of the report did not earn $100; two-thirds launch with fewer than 10,000 wishlists | Steamworks docs; press summaries of Gamalytic/VG Insights data (S21, S22) |
| Web-first virtual spaces | Gather (browser, no install) reports "more than 4 million users"; adoption studies list organisational restrictions and privacy of side conversations as friction, not download | Product listings and a usability study (S23) |
| Mobile stores | Apple: $99/year developer programme, 15% commission under the Small Business Program up to $1M; Google Play: $25 one-off registration, 15% on the first $1M | Apple and Google developer pages via summaries (S24) |

Reading for Agentnagar: a downloadable client is a retention tool for people
who already care, not a discovery channel for a free social/sim experience.
Steam's fee is trivial; its visibility is not, and a free "watch agents work"
title competes with 12,000+ releases a year. Mobile stores add review,
signing and fee overheads that only pay back once in-app purchases (RD07)
exist. None of this argues against a native client; it argues that the link
must work first and the download must be optional (the platform brief already
says native-only transports must not gate entry).

### What "watching agents work" implies

- **Second-screen and ambient use.** A viewer leaves the tab open beside
  their own work. Browsers throttle hidden tabs (section 3), so "live" must
  be re-established on return, and a page that plays audio to stay awake is
  hostile. Design for "catch me up" on focus, not for a tab that never sleeps.
- **Embeds.** Streamers, blog posts and READMEs will want a single agent's
  workbench or a district as an iframe. Cross-origin isolation (needed only
  for threads) and iframe restrictions on IndexedDB in Safari (S25) bear on
  this.
- **Streaming.** A live video stream of the city is the cheapest universal
  client and costs nothing on the viewer's GPU. Captions and a transcript
  then become the accessibility surface (section 4).
- **Shareable links to a moment or place.** A URL that names a place, an
  agent and a time (`/guild/dev/2026-09-18T09:30+05:30`) makes a fleeting
  observation citable and lets a text page render the same moment for search
  engines, screen readers and slow networks.

## 2. Device and network baseline

### Desktop class (Steam Hardware Survey, August 2026)

Steam samples gamers, which overstates GPUs relative to the general public;
it is still the best public hardware census.

| Measure | Values | Source |
| --- | --- | --- |
| OS | Windows 94.0% (Win 11 71.0%, Win 10 22.9%), Linux 3.9%, macOS 2.1% | S26 |
| System RAM | 16 GB 41.2%, 32 GB 37.5%, 8 GB 7.5%, 4 GB 1.4% | S26 |
| VRAM | 16 GB 26.9%, 8 GB 25.7%, 12 GB 13.0%, 4 GB 5.7%, 2 GB 4.1% | S26 |
| Physical cores | 8: 28.0%, 6: 27.4%, 4: 12.5% | S26 |
| Resolution | 1920x1080 50.5%, 2560x1440 21.9%, 1366x768 2.2% | S26 |
| Top cards | RTX 3060, RTX 4060 Laptop, RTX 4060, RTX 3050, RTX 5060; GTX 1650 still 2.4% | S26 |
| Language | English 38.3%, Simplified Chinese 24.0%, Russian 9.9%, Spanish 4.5%, Portuguese (BR) 4.0% | S26 |

The general laptop baseline is far below this. Alex Russell's 2026
performance-inequality baseline names an HP 14 with a 4-core Celeron N4500,
eMMC storage and Windows, under $250 new, as the P75 desktop (S3).

### Phone class

| Measure | Value | Source |
| --- | --- | --- |
| P75 phone (global) | Samsung Galaxy A24 4G: MediaTek Helio G99, launched at $250; alternatives Galaxy A16 4G, Redmi Note 13 Pro 4G | S3 |
| Median global smartphone ASP | about $370 (2025); iPhone under 20% of new shipments | S3 |
| iOS share by market | India 7.2%, worldwide 32.4%, US 60.7% (Aug 2026) | S18 |
| RAM on the P75 class | 4–8 GB variants exist for the A24/A16 class; treat 6 GB as the reference and 4 GB as the floor (proposal; vendor spec pages not fetched) | S3 |

A Helio G99 or Snapdragon 4-/6-series phone with 4–6 GB RAM is what most of
the world and nearly all of India's Android base will bring. iOS Safari's
memory ceiling for a tab is the other hard wall (section 3).

### Network and data cost

| Region / country | Median mobile down (Mbps) | Median fixed down (Mbps) | 1 GB mobile data (USD) | Sources |
| --- | --- | --- | --- | --- |
| India | 130.9 | 61.6 | 0.16 | S27, S17 |
| Indonesia | 50.8 | 43.2 | 0.28 | S27, S17 |
| Philippines | 54.4 | 108.0 | 0.59 | S27, S17 |
| Vietnam | 160.5 | 273.6 | 0.29 | S27, S17 |
| Nigeria | 43.7 | 31.1 | 0.39 | S27, S17 |
| Kenya | 48.2 | 15.9 | 0.59 | S27, S17 |
| South Africa | 68.0 | 48.3 | 1.81 | S27, S17 |
| Egypt | 46.2 | 91.6 | 0.65 | S27, S17 |
| Brazil | 256.7 | 219.8 | 0.40 | S27, S17 |
| Mexico | 40.7 | 91.8 | 2.03 | S27, S17 |
| Germany | 76.9 | 102.0 | 2.14 | S27, S17 |
| France | 147.5 | 346.0 | 0.20 | S27, S17 |
| United Kingdom | 71.8 | 162.8 | 0.62 | S27, S17 |
| United States | 185.0 | 302.7 | 6.00 | S27, S17 |

Speeds are Speedtest Global Index medians for December 2025 read through a
secondary page (S27); speedtest.net itself could not be fetched. Medians hide
the slow tail: Russell's P75 network is 9 Mbps down, 3 Mbps up, 100 ms RTT
worldwide, and 6.2 Mbps / 85 ms for India, 6.4 Mbps / 75 ms for Indonesia
(S3). No p10 figures were found in this pass; the P75 values are the nearest
primary evidence for "the slow quarter". Data cost matters less than it did:
India is among the cheapest markets; Sub-Saharan Africa ($3.31 average) and
North America ($4.59) are the expensive regions in the cable.co.uk set (S17).

For scale, the median web page in October 2024 weighed 2,311 KB on mobile
(558 KB JavaScript, 900 KB images), and the 90th percentile 7,680 KB (S4).

### Proposed reference classes (proposals, not decisions)

| Class | Definition | Initial payload (proposal) | Memory ceiling (proposal) | Frame-time target (proposal) | Why |
| --- | --- | --- | --- | --- | --- |
| **Modest phone** | Galaxy A24 4G or equivalent: Helio G99, 6 GB RAM, 1080x2340, Chrome for Android; secondary: iPhone SE/11-class on current iOS Safari | ≤ 2.0 MiB critical path for a usable first view; ≤ 3.7 MiB to a full 5-second experience on 9 Mbps | ≤ 300 MB total tab memory (JS heap + WASM + GPU) | 33 ms (30 fps) sustained; no frame over 100 ms while text is being typed | Russell's 3 s / 5 s budgets for a JS-light page (S3); iOS Safari tab-termination reports cluster around WASM heaps growing past 256 MB (S8); WCAG-style input responsiveness |
| **Modest laptop** | HP 14 with Celeron N4500, 4 GB or 8 GB RAM, integrated graphics, 1366x768, Chrome or Edge on Windows 10/11 | Same payload as phone; a larger scene may stream after first paint | ≤ 1 GB tab memory | 16.7 ms (60 fps) at 1366x768 with the first-slice scene; 33 ms acceptable | Russell's P75 desktop (S3); Steam shows 1366x768 still present (S26); integrated graphics handle WebGL 2 stylised scenes but not heavy post-processing |

Set the budgets before any comparison is run (the platform brief's
comparison design) so that the numbers are not chosen after seeing results.
A native desktop client can target the Steam class instead, but the browser
entrance should be measured against these two.

## 3. Platform capability facts (as of 2026-09-18)

### Rendering, compute and memory

| Capability | Status | Source |
| --- | --- | --- |
| WebGL 2 | 96.4% global coverage; Safari and iOS Safari since 15, Chrome 56, Firefox 51, Edge 79, Samsung 7.2. Godot's docs still warn Safari "has several issues with WebGL 2.0 support that other browsers don't have" | S5, S28 |
| WebGPU | 87.4% global coverage on caniuse. Chrome/Edge since 113 on Windows, macOS, ChromeOS; Chrome Android since 121 for ARM/Qualcomm/Intel on Android 12+, Imagination since 139, Samsung Xclipse "probably 154"; Linux only on Intel Gen12+ (144) and NVIDIA on Wayland (147). Safari 26 on macOS, iOS, iPadOS, visionOS (caniuse marks macOS partial). Firefox 141 on Windows, 145/147 on Apple-silicon macOS; Linux and Android still nightly/flagged, "expected 2026". Samsung Internet 24+ | S6, S29 |
| WebAssembly memory | Unity's Web heap "can expand up to 4 GB" but growth "can cause your application to crash if the browser fails to allocate a contiguous memory block"; Unity says mobile browsers need the advanced memory options tuned. Emscripten and Unity forum reports: iOS Safari "much more aggressively terminates tabs for high memory usage", with crashes reported when heaps grow from 256 MB towards 300–500 MB; iOS 18.2/18.3 WebGL crash reports on load | S8, S30 |
| Threads / SharedArrayBuffer | 96.2% coverage (Chrome 68, Firefox 79, Safari 15.2, Edge 79) but only in cross-origin-isolated pages (COOP/COEP headers), which also constrains third-party embeds and iframes. Godot exports single-threaded by default since 4.3 and needs isolation only when threads are on | S31, S28 |
| Godot web export | WebAssembly + WebGL 2 Compatibility renderer only; "does not support WebGPU", so Forward+/Mobile renderers cannot run on the web; C# projects "cannot be exported to the web"; mobile CPU/GPU "at a premium" | S28 |
| Unity Web | Requires WebGL 2, 64-bit browsers with WebAssembly; iOS Safari 15+ and Chrome 58+ on Android supported; Safari cannot use IndexedDB inside an iframe | S25 |

### Transport and lifecycle

| Capability | Status | Source |
| --- | --- | --- |
| WebSocket | Universal; browsers exempt it from background throttling to avoid closures | S14 |
| WebTransport (HTTP/3) | 91.3% coverage: Chrome 97, Edge 98, Firefox 114, Safari and iOS Safari 26.4, Samsung 18 | S32 |
| WebRTC data channels | 97.0% coverage (Chrome 23, Firefox 22, Safari 11) | S33 |
| Background tabs (Chrome 88+) | Hidden pages: timers once per second; after 5 hidden minutes, with a chain of 5+ timers, 30 s of silence and no WebRTC, once per minute. requestAnimationFrame does not run at all while hidden. Audio in the last 30 s or an open RTCDataChannel exempts a page from intensive throttling. Firefox budget-throttles after 30 s; Chrome after 10 s | S14, S34 |
| PWA install | Android Chrome: automatic `beforeinstallprompt`; desktop Chrome/Edge: URL-bar install icon; iOS/iPadOS: manual Add to Home Screen from the share sheet, no prompt; Firefox desktop: extension only | S35 |
| Web push on iOS | Since iOS/iPadOS 16.4 (Feb 2023), only for web apps added to the Home Screen with `display: standalone` or `fullscreen`; permission must follow a user tap; Badging API available | S36 |
| Audio autoplay | Audible playback needs prior user interaction, an allowlisted site or Permissions Policy; muted media is exempt; Web Audio `AudioContext` starts suspended in Firefox until sticky activation and behaves similarly elsewhere | S37 |

### Text input, IME and scripts (comments and messages are core)

| Topic | Fact | Source |
| --- | --- | --- |
| Keyboard inside a canvas | The on-screen keyboard appears only when an editable element (input, textarea, contenteditable) has focus; a bare canvas never raises it. The VirtualKeyboard API (`overlaysContent`, `geometrychange`, `keyboard-inset-*` variables) is Chrome/Edge only, not Safari or Firefox | S7 |
| EditContext API | Lets a canvas or custom surface receive native IME composition (Japanese, Chinese, Korean), emoji pickers and platform editing UI; Chrome, Edge and Firefox support it, Safari does not, so it is not Baseline | S9 |
| Why canvas apps overlay DOM text | Hidden textareas give "limited IME support, accessibility issues"; DOM inputs give IME, autocorrect, spellcheck, paste, dictation, password managers, screen readers and Indic keyboards for free | S9 |
| Complex-script shaping in engines | Godot's default TextServerAdvanced "uses HarfBuzz, ICU and SIL Graphite to support BiDi, complex text layouts and contextual OpenType features"; TextServerFallback is "without support for BiDi and complex text layout". Godot mirrors layouts for RTL and ships ~4 MB of ICU break-iterator data for languages written without spaces | S10, S38 |
| Complex-script shaping in Three.js text | troika-three-text supports RTL/bidi, ligatures and "joined scripts like Arabic" with Noto fallback fonts; Indic scripts are not listed as supported | S39 |
| DOM text | Browsers shape Devanagari, Tamil, Arabic, CJK and mixed-direction text with system fonts and no payload; the cheapest correct path for user text | S7, S9 (inference) |

### Constraints by delivery route

| Route | What it costs the audience | What it costs the project | Notes |
| --- | --- | --- | --- |
| Web 2D (DOM/Canvas 2D/SVG) | Least: runs on every device in S2/S18; text stays native | Loses depth and spectacle; fine for the "text city" and embeds | No engine facts needed |
| Web 3D on WebGL 2 | ~96% coverage; Safari quirks; iOS memory wall; must ship single-threaded or set COOP/COEP | Compatibility renderers only in engines that export to web | S5, S28, S31 |
| WebGPU | ~87% coverage today; Firefox default-off, Linux patchy, macOS Safari partial | Must keep a WebGL 2 fallback for years | S6, S29 |
| Native desktop | Download, signing, updates; Windows 94% of Steam, Linux 4%, macOS 2% | Packaging for three OSs; no discovery on its own | S26, S21 |
| Native mobile | Store friction and fees; Android 93% in India, iOS 61% in the US | Two store programmes, review cycles, 15% commission | S18, S24 |
| PWA | Free "install" on Android and desktop; manual on iOS; push only from Home Screen on iOS | Manifest, service worker, offline shell; no store fees | S35, S36 |

## 4. Accessibility

### Standards to adopt as the written baseline

| Standard | What it is | Relevance | Source |
| --- | --- | --- | --- |
| WCAG 2.2 Level AA | W3C Recommendation, 5 Oct 2023; adds 2.4.11 Focus Not Obscured, 2.5.7 Dragging Movements, 2.5.8 Target Size (24x24 CSS px), 3.2.6 Consistent Help, 3.3.7 Redundant Entry, 3.3.8 Accessible Authentication; removes 4.1.1 Parsing | The baseline for every DOM surface: site, text city, comments, assemblies. Proposal: adopt 2.2 AA in writing now | S11 |
| Game Accessibility Guidelines | Community guidance in Basic/Intermediate/Advanced tiers across motor, cognitive, vision, hearing, speech and general; e.g. "Allow controls to be remapped", "Ensure no essential information is conveyed by a fixed colour alone", "Provide subtitles for all important speech", "Ensure that all settings are saved/remembered" | The baseline for the spatial client, where WCAG does not reach | S40 |
| Xbox Accessibility Guidelines v3.2 (June 2023) | Microsoft's per-topic guidance with scoping questions and implementation guidelines; "aren't intended to act as a checklist to validate any type of compliance or legal requirements" | Useful structure for testing; not a legal bar | S41 |
| EN 301 549 v3.2.1 | The EU harmonised ICT standard; clause 9 (web) points at WCAG 2.1 AA and clause 11 covers non-web software. The ETSI PDF was fetched but not text-readable in this pass; version from the document URL | What EU conformity would be measured against | S42 |

### Legal exposure (facts, not advice)

| Regime | What the sources say | Likely position for a solo non-EU service |
| --- | --- | --- |
| European Accessibility Act (Directive 2019/882), in application since 28 June 2025 | Covers "e-commerce services" provided "at a distance, through websites and mobile device-based services ... with a view to concluding a consumer contract". "Service provider" is "any natural or legal person who provides a service on the Union market or makes offers to provide such a service to consumers in the Union" — establishment outside the EU is not an exemption. Article 4(5): "Microenterprises providing services shall be exempt", where a microenterprise employs fewer than 10 persons and has turnover or balance sheet not exceeding EUR 2 million | Selling residency or credits (RD07, RD09) to EU consumers is e-commerce in scope; the microenterprise exemption plausibly applies while SJL stays under 10 people and EUR 2 million, but it is an exemption from requirements, not from the market, and it ends with growth. Watching agents for free is not e-commerce. Verify with counsel before the first EU sale (S43) |
| US ADA | The 2024 DOJ rule (WCAG 2.1 AA) binds Title II state and local governments only, with deadlines now April 2027/2028; private websites remain under Title III case law with no codified standard | Litigation exposure exists for consumer sites; WCAG 2.2 AA is the conventional defence. Section 508 applies only to federal procurement (S44) |
| India RPwD Act 2016 and GIGW 3.0 | GIGW 3.0 (Guidelines for Indian Government Websites and Apps) is the government standard with accessibility and screen-reader resources; it binds government sites and apps. The Act's service-provider obligations and the rules adopting GIGW/IS 17802 were not re-read in this pass | No direct obligation on a private global product found; GIGW is a useful local reference for Indic-language accessibility (S45) |

### State of screen-reader support in spatial clients (facts only)

| Runtime | State | Source |
| --- | --- | --- |
| DOM / HTML | Full: every browser exposes DOM to platform accessibility APIs; ARIA live regions, roles and names work on desktop and mobile | S11 |
| Godot 4.5 (Sept 2025) | "Thanks to AccessKit, we added screen reader support to Control nodes, and we also added screen reader bindings in order to customize the behavior of any type of Node." Marked "still in its experimental phase"; editor support partial; reporting at release named mobile and web integration as remaining work. The web export page does not mention screen readers | S12, S28 |
| Unity 6 | Accessibility module with `AssistiveSupport` and an accessibility hierarchy; supports Android TalkBack, iOS VoiceOver and, since 6000.3, Windows Narrator and macOS VoiceOver. Web is not in the supported list | S13 |
| Bevy | `bevy_a11y` integrates AccessKit; AccessKit 0.25 bumped 16 Sept 2026; 0.19 added `AccessibleLabel`. First engine with built-in AccessKit (0.10) | S46 |
| Flutter web | Renders to canvas and mirrors a semantics tree into `<flt-semantics>` DOM nodes, but only after the user presses an invisible "Enable accessibility" button or the app calls `ensureSemantics()` | S47 |
| Canvas-only web games | No accessibility tree unless the app builds a parallel DOM; the EditContext and VirtualKeyboard APIs help input, not exposure | S7, S9 |

The common thread: in September 2026 no game engine exposes its scene to a
browser's accessibility tree on the web. A web spatial client therefore needs
a DOM equivalent regardless of engine, which the repo already promises
("accessible direct entry throughout", "the same programme with direct-entry
links and captions" in the city plan and daily-life journeys).

### Patterns that make a spatial world usable without sight or fine motor control

- **A parallel DOM "text city".** Every district, facility, agent and work
  item has a readable page at a stable URL; the map is a list and a table;
  the 3D scene deep-links to the same IDs. This is the WCAG 1.1.1 / 1.3.1
  equivalent and also the search-engine, slow-network and embed surface.
- **Direct entry.** "Go to Dev's workbench" as a command palette or search,
  not only as a walk. Keyboard: Tab order through places; arrow keys or WASD
  to move; Enter to open; Escape to leave. Switch access reduces to the same
  sequential focus model.
- **Work state as text and semantics, not colour.** Agent states (idle,
  working, waiting on review, blocked, offline) need a name, an icon shape
  and a colour, and the name must be in an ARIA live region when it changes
  for a followed agent. Choose the colour set against deuteranopia and
  protanopia; the Game Accessibility Guidelines' "no essential information by
  a fixed colour alone" is the rule (S40).
- **Captions and transcripts.** Any voice (agent read-aloud, assembly audio)
  needs captions in the DOM and a transcript page; the repo already states
  that audio never makes captions optional.
- **Reduced motion and photosensitivity.** Honour `prefers-reduced-motion`
  for camera sway, weather, and idle animation; keep any flashing under
  WCAG 2.3.1's three flashes per second and area thresholds (S48).
- **Remappable controls and target size.** WCAG 2.5.8 requires 24x24 CSS px
  targets; the GAG basic tier asks for remapping and a simpler alternative to
  each control scheme (S11, S40).
- **Cognitive load.** One thing happening at a time on first visit; plain
  language for work states; consistent help placement (WCAG 3.2.6).
- **Chat accessibility.** Comments and messages in the DOM with `role="log"`
  live regions, a user-set rate limit on announcements, pause/resume, and
  no auto-scrolling away from what a screen-reader user is reading.

### First-slice checklist (observe agents, read work state, comment)

Each line is meant to be testable by one person with a keyboard, a screen
reader (NVDA on Windows, VoiceOver on macOS/iOS, TalkBack on Android) and a
modest phone. Proposal.

| # | Requirement | Test |
| --- | --- | --- |
| A1 | Every agent and place in the first slice has a readable DOM page at a stable URL that shows the same work state the scene shows | Open both; states match within the stated freshness window |
| A2 | The scene is reachable by keyboard alone: focus visible, no trap, Escape returns to the page | Tab through; run WCAG 2.4.11 focus-not-obscured check |
| A3 | Agent work-state changes for a followed agent are announced once, as text, in a polite live region | NVDA/VoiceOver hears "Dev: waiting on review" |
| A4 | Work states are distinguishable by name and shape, and the colour set passes a colour-blindness simulation | Simulate deuteranopia; states still distinct |
| A5 | Comment box is a DOM `<textarea>` with a label, works with Indic and CJK IMEs, dictation and paste; on phone the keyboard does not hide the box | Type Hindi and Japanese on Android and iOS |
| A6 | Comment list is a live region with user-controlled rate and pause | Screen reader can pause announcements |
| A7 | `prefers-reduced-motion` removes camera sway, weather and idle bobbing | Toggle OS setting; motion stops |
| A8 | Nothing flashes more than three times a second | Review effects list; PEAT or manual check |
| A9 | All text meets 4.5:1 contrast at the default size and scales to 200% without loss | Zoom; contrast tool |
| A10 | Touch targets are at least 24x24 CSS px; no drag-only interaction | Phone walkthrough |
| A11 | The page is usable within 5 s on the modest phone over a 9 Mbps / 100 ms throttle, with the text city usable within 3 s | DevTools throttling on a real device |
| A12 | Audio never starts without a gesture; captions exist for any agent voice | Load with sound on; nothing plays |
| A13 | Returning to a backgrounded tab restores the live state without reload | Hide for 10 minutes; return |
| A14 | The accessibility statement page names WCAG 2.2 AA as the target and lists known gaps | Page exists and is linked from the entrance |

### Later-slice list

- Assemblies: real-time captions, a transcript, hand-raise by keyboard,
  text-only participation, time-shifted playback with captions.
- Messages: notification rate control, do-not-disturb per time zone, and
  screen-reader-friendly threading.
- Building and placing: keyboard and single-switch placement; no drag-only
  or timing-only actions; undo everywhere.
- Native clients: AccessKit or platform screen-reader exposure verified per
  OS release; the text city remains the guaranteed path.
- Photosensitivity review of festivals, night market neon and weather.
- Cognitive: a "quiet mode" that reduces simultaneous agents on screen;
  glossary for work-state terms; consistent help.
- Speech input as an alternative, never a requirement.
- Regular testing with disabled makers, paid, once there is something to test.

## 5. Localisation and time zones

| Topic | Evidence and options | Proposal |
| --- | --- | --- |
| UI language priority | Developer respondents: US 20%, Germany 9%, India 7%, UK 6%, France 4% (S16); GitHub growth: India, Brazil, Indonesia, Nigeria, Egypt (S15); Steam: English 38%, Simplified Chinese 24%, Russian 10%, Spanish 5%, Brazilian Portuguese 4% (S26) | English first; then Hindi, Brazilian Portuguese, Spanish, Simplified Chinese, Indonesian, and a plan for Arabic (RTL) and Japanese. Order by observed visitors, not by guess |
| Agents' working language | The Guild works in English code, commits and reviews; that is what visitors watch | Agents work in English; the client translates *labels and summaries*, not the work artefacts |
| Machine translation of comments and messages | Options: Google Cloud Translation, DeepL API, or a self-hosted model on the lab server. Both vendor pricing pages resisted fetching in this pass, so no figures are quoted; both charge per character with a free tier. Privacy: sending user messages to a third party needs disclosure in the privacy notice and a per-message opt-out; self-hosting keeps text on SJL infrastructure at compute cost | Translate on demand ("Translate this comment"), cache per message, label the result as machine translation, and never translate private messages without both parties' setting |
| Displaying time | The agents run on IST (UTC+05:30); visitors are global | Show local time by default with the city time alongside ("09:30 city time · 04:00 UTC · your 06:00"); store UTC; label assemblies with a UTC anchor and a local conversion; publish an ICS link |
| RTL readiness | Godot mirrors anchors, margins and container order for RTL (S38); DOM does it with `dir="rtl"` and logical CSS properties | Use logical properties from the first stylesheet; test one RTL locale early even if it ships late |
| Font and payload cost of multi-script support | Godot's ICU break-iterator data is ~4 MB if bundled (S38); Noto fallback sets for Devanagari, Tamil, Arabic and CJK add several MB each in an engine build; DOM text uses system fonts at zero payload | Keep user text in the DOM; subset any in-scene font to the labels it draws; load script-specific fonts lazily |
| Naming and cultural-sensitivity review | Agentnagar, Agentganj and Agent City are open (RD17); "nagar" and "ganj" are Hindi/Urdu place words | Before naming, run a 10-language check of the candidate for meaning and pronunciation; review agent names, festival names and iconography (colours of flags, gestures, religious symbols) with people from at least the top five visitor countries |

## 6. Cheap evidence-gathering steps and open questions

Steps the owner can take without building the city (proposals):

1. **Read the existing site's analytics** by device class, OS, browser,
   country and connection type for the last 90 days. This answers the
   "developer sites skew desktop" assumption directly.
2. **Borrow or buy one modest Android phone** (Galaxy A24/A16 class, ~$150
   used) and keep it on a 9 Mbps throttle for every prototype check. Add one
   older iPhone if the US matters.
3. **Landing-page test.** Two variants of the same page: "Watch the agents
   now (no sign-up)" versus "Download the city". Measure clicks, not
   opinions. A few hundred visits from a developer forum post is enough to
   see a 3x gap if it exists (S1).
4. **Five to eight interviews** with target makers, half outside India,
   including at least one screen-reader user and one person on a 4 GB phone.
   Ask what they would want to see in the first 30 seconds.
5. **Embed test.** Put a static "agent status card" iframe in a README and
   a blog post; see whether anyone clicks through.
6. **Time-zone probe.** Announce one open assembly at 09:30 IST and one at
   19:30 IST; record who turns up.
7. **Run an automated WCAG check** (axe, Lighthouse) on the current site so
   the baseline is known before the city inherits it.

Open questions this brief cannot answer from the desk:

- Actual first-view payload and memory of any candidate client on the modest
  phone; the platform brief's comparison would produce this.
- Whether the audience arrives mainly from developer channels (desktop) or
  social sharing (mobile); the analytics and landing test answer this.
- Which agent work-state fields are public (RD01 opens) and therefore what
  the live region must say.
- Whether EU sales start before the microenterprise exemption stops
  applying, and what the accessibility statement must say in each market.
- Machine-translation cost at the expected comment volume; vendor prices
  need re-fetching.
- GIGW 3.0's exact WCAG level and the RPwD rules' reach to private services.

## Sources

Accessed 2026-09-18 unless stated.

- S1. How To Market A Game, "Benchmark: Itch.io traffic" (12 May 2025):
  <https://howtomarketagame.com/2025/05/12/benchmark-itch-io-traffic/>
- S2. StatCounter, desktop vs mobile vs tablet, worldwide and India, August
  2026: <https://gs.statcounter.com/platform-market-share/desktop-mobile-tablet>
  and <https://gs.statcounter.com/platform-market-share/desktop-mobile-tablet/india>
- S3. Alex Russell, "The Performance Inequality Gap, 2026" (Nov 2025):
  <https://infrequently.org/2025/11/performance-inequality-gap-2026/>
- S4. HTTP Archive Web Almanac 2024, Page Weight:
  <https://almanac.httparchive.org/en/2024/page-weight>
- S5. caniuse, WebGL 2.0: <https://caniuse.com/webgl2>
- S6. caniuse, WebGPU: <https://caniuse.com/webgpu>
- S7. MDN, VirtualKeyboard API:
  <https://developer.mozilla.org/en-US/docs/Web/API/VirtualKeyboard_API>
- S8. Unity Manual, Memory in Web:
  <https://docs.unity3d.com/6000.2/Documentation/Manual/webgl-memory.html>;
  Unity Discussions, "WebGL memory increment issue and crash on iOS":
  <https://discussions.unity.com/t/webgl-memory-increment-issue-and-crash-on-ios/894771>;
  emscripten-discuss, "Wasm crashing on iPhone":
  <https://groups.google.com/g/emscripten-discuss/c/SlmrsE9hpwE>;
  Apple Developer Forums, "WebGL is crashing in IOS 18.2 and 18.3":
  <https://developer.apple.com/forums/thread/778735>
- S9. MDN, EditContext API:
  <https://developer.mozilla.org/en-US/docs/Web/API/EditContext_API>
- S10. Godot docs, TextServerAdvanced and TextServerFallback:
  <https://docs.godotengine.org/en/stable/classes/class_textserveradvanced.html>,
  <https://docs.godotengine.org/en/stable/classes/class_textserverfallback.html>
- S11. W3C WAI, "What's New in WCAG 2.2":
  <https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/>
- S12. Godot, "Godot 4.5, making dreams accessible":
  <https://godotengine.org/releases/4.5/>; Can I Play That, "Godot 4.5
  improves accessibility support" (29 Apr 2025):
  <https://caniplaythat.com/2025/04/29/godot-4-5-improves-accessibility-support-including-screen-readers/>
- S13. Unity Manual, Introduction to the Accessibility module:
  <https://docs.unity3d.com/6000.4/Documentation/Manual/accessibility/module-intro.html>;
  Unity Discussions, "Native desktop screen reader support now available in
  Unity 6.3": <https://discussions.unity.com/t/native-desktop-screen-reader-support-now-available-in-unity-6-3/1681788>
- S14. Chrome Developers, "Heavy throttling of chained JS timers beginning
  in Chrome 88": <https://developer.chrome.com/blog/timer-throttling-in-chrome-88>
- S15. GitHub Octoverse 2025:
  <https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/>
- S16. Stack Overflow Developer Survey 2025, Developers:
  <https://survey.stackoverflow.co/2025/developers>
- S17. cable.co.uk Worldwide Mobile Data Pricing (page now at
  <https://bestbroadbanddeals.co.uk/mobiles/worldwide-data-pricing/>);
  survey year shown ambiguously on the page; Mappr's summary of the June 2026
  edition gives the same US and Germany values:
  <https://www.mappr.co/mobile-data-pricing-by-country/>
- S18. StatCounter, mobile OS share, worldwide, India, US, August 2026:
  <https://gs.statcounter.com/os-market-share/mobile/worldwide>,
  <https://gs.statcounter.com/os-market-share/mobile/india>,
  <https://gs.statcounter.com/os-market-share/mobile/united-states-of-america>
- S19. StatCounter, desktop OS share, worldwide, August 2026:
  <https://gs.statcounter.com/os-market-share/desktop/worldwide>
- S20. StatCounter, browser share, worldwide, August 2026:
  <https://gs.statcounter.com/browser-market-share>
- S21. Steamworks, Steam Direct Fee:
  <https://partner.steamgames.com/doc/gettingstarted/appfee>
- S22. PC Gamer on 2025 Steam releases and the $100 threshold:
  <https://www.pcgamer.com/games/with-over-13-000-new-games-on-steam-this-year-so-far-over-a-third-of-them-havent-even-made-enough-to-break-even-on-valves-submission-fee/>;
  GameDiscoverCo, "The state of Steam wishlist conversions: 2024-2025":
  <https://newsletter.gamediscover.co/p/the-state-of-steam-wishlist-conversions>
- S23. Product Hunt, Gather Town: <https://www.producthunt.com/products/gather-town>;
  ResearchGate, comparative usability study of Spatial.io, Gather.town and
  Zoom: <https://www.researchgate.net/publication/362754598>
- S24. Apple, App Store Small Business Program:
  <https://developer.apple.com/app-store/small-business-program/>; Google
  Play Console Help, "Understanding Google Play's service fee":
  <https://support.google.com/googleplay/android-developer/answer/11131145>
- S25. Unity Manual, Web browser compatibility:
  <https://docs.unity3d.com/6000.2/Documentation/Manual/webgl-browsercompatibility.html>
- S26. Steam Hardware & Software Survey, August 2026:
  <https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam>
- S27. World Population Review, "Internet Speeds by Country 2026" (Speedtest
  Global Index, December 2025 medians; secondary):
  <https://worldpopulationreview.com/country-rankings/internet-speeds-by-country>
- S28. Godot docs, Exporting for the Web:
  <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html>
- S29. gpuweb wiki, Implementation Status:
  <https://github.com/gpuweb/gpuweb/wiki/Implementation-Status>
- S30. Bugnet, "Fix: Unity WebGL build crashing on Safari iOS":
  <https://bugnet.io/blog/how-to-fix-unity-webgl-build-crashing-on-safari-ios>
- S31. caniuse, SharedArrayBuffer: <https://caniuse.com/sharedarraybuffer>
- S32. caniuse, WebTransport: <https://caniuse.com/webtransport>
- S33. caniuse, WebRTC Peer-to-peer connections:
  <https://caniuse.com/rtcpeerconnection>
- S34. MDN, Page Visibility API:
  <https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API>
- S35. MDN, Installing and uninstalling web apps:
  <https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Installing>
- S36. WebKit blog, "Web Push for Web Apps on iOS and iPadOS":
  <https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/>
- S37. MDN, Autoplay guide for media and Web Audio APIs:
  <https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay>
- S38. Godot docs, Internationalizing games:
  <https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html>;
  Using Fonts: <https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html>
- S39. troika-three-text README:
  <https://github.com/protectwise/troika/blob/main/packages/troika-three-text/README.md>
- S40. Game Accessibility Guidelines, full list:
  <https://gameaccessibilityguidelines.com/full-list/>
- S41. Microsoft, Xbox Accessibility Guidelines (v3.2, 8 Jun 2023; page
  updated 14 Aug 2026):
  <https://learn.microsoft.com/en-us/gaming/accessibility/guidelines>
- S42. ETSI EN 301 549 v3.2.1 (PDF fetched, not text-readable here):
  <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/03.02.01_60/en_301549v030201p.pdf>
- S43. Directive (EU) 2019/882, the European Accessibility Act:
  <https://eur-lex.europa.eu/eli/dir/2019/882/oj/eng>
- S44. US DOJ, "Fact Sheet: New Rule on the Accessibility of Web Content and
  Mobile Apps Provided by State and Local Governments":
  <https://www.ada.gov/resources/2024-03-08-web-rule/>
- S45. GIGW 3.0, Guidelines for Indian Government Websites and Apps:
  <https://guidelines.india.gov.in/>
- S46. Bevy, `bevy_a11y` and AccessKit: <https://docs.rs/bevy/latest/bevy/a11y/index.html>;
  Bevy PR #25807 (AccessKit 0.25): <https://github.com/bevyengine/bevy/pull/25807>;
  AccessKit announcement: <https://accesskit.dev/accesskit-integration-makes-bevy-the-first-general-purpose-game-engine-with-built-in-accessibility-support/>
- S47. Flutter docs, Web accessibility:
  <https://docs.flutter.dev/ui/accessibility/web-accessibility>
- S48. W3C, Understanding SC 2.3.1 Three Flashes or Below Threshold:
  <https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html>
