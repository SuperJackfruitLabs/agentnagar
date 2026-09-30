# Atmosphere and effects

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Effects express place, time, weather and activity. They should be attached to meaningful events or regions and scaled independently from object ownership and gameplay state.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| FX-01 | **Daylight and sky environment.** Time-of-day illumination and skyline backdrop. | Effect | Time source, color, sun direction, transition, exposure and quality variants. | Transition by world/environment rules; personal visual settings do not change simulation time. |
| FX-02 | **Rain, snow and wind.** Regional weather presentation. | Effect | Region, intensity, direction, particles, sound and visibility limits. | Start/change/stop; weather visuals do not imply flooding, damage or crop effects. |
| FX-03 | **Wetness, puddles and footprints.** Surface response conveying recent weather or movement. | Effect | Affected surface, intensity, lifetime, reflection treatment and fade. | Appear/fade; transient presentation does not create owned puddle objects. |
| FX-04 | **Ambient sound zone.** Spatial sound identity for a street, interior or waterfront. | Effect | Bounds, sound layers, falloff, volume, schedule and mute behavior. | Enter/leave/mix; essential information also available visually or as text. |
| FX-05 | **Activity and machine feedback.** Visible or audible indication of meaningful work state. | Effect | Source state, duration, attachment, repetition and intensity. | Show running/complete/fault; decorative activity must not falsify real agent work status. |
| FX-06 | **Interaction animation and cue.** Feedback for pickup, placement, storage or denied action. | Effect | Trigger, target, timing, cancellation, sound/text and reduced-motion version. | Play/cancel; feedback follows accepted state and clearly distinguishes pending action. |
| FX-07 | **Distant population and traffic representation.** Lightweight background impression at city scale. | Effect | Density envelope, route association, distance transitions and identity policy. | Aggregate/fade; never replace an owned or interacted entity with an unrelated identity. |
| FX-08 | **Event decoration and celebration effect.** Temporary visual atmosphere for a gathering or achievement. | Effect | Trigger authority, region, duration, intensity and reduced-motion controls. | Start/stop; event effects do not modify participants' possessions. |
