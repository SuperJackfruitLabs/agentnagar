# Residents and appearance

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Residents are identities with agency, not tradable inventory. Visual clothing and equipment can be owned assets; no trade of an avatar grants control over a person, agent credentials or a private runtime.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| RES-01 | **Human resident avatar.** Embodied representation of a person in the city. | Entity | Identity reference, body proportions, locomotion, customization, presence and visibility. | Move/interact/emote under account grants; avatar is not a saleable resident. |
| RES-02 | **Agent resident representation.** Embodied interface to an agent's permitted presence and work. | Entity | Agent identity reference, disclosure, public state, freshness, interaction anchors and privacy. | Observe/converse/request only within grants; moving appearance does not migrate runtime. |
| RES-03 | **Background population character.** Ambient resident used to give public spaces life. | Entity | Role, route/activity schedule, variation seed, crowd detail and interaction depth. | Ambient movement; explicitly distinguish authored simulation from a real working agent. |
| RES-04 | **Clothing and footwear.** Wearable appearance items. | Portable | Compatible body/rig, equip slots, size variants, material, palette and clipping bounds. | Equip/unequip/customize/store/trade when eligible; avatar identity stays unchanged. |
| RES-05 | **Accessory and wearable device.** Glasses, hat, badge holder or device worn on the body. | Portable | Attachment slot, fit, visibility, interaction affordance and effect if any. | Equip/inspect; cosmetic devices do not grant service permissions. |
| RES-06 | **Hair, face and body customization.** Identity-preserving appearance options. | Fixed | Rig compatibility, proportions, palette, expression support and accessibility preferences. | Change appearance through profile editing; not loose portable body parts. |
| RES-07 | **Pose, expression and emote.** Reusable authored character performance. | Effect | Rig compatibility, duration, blend, interruption and social meaning. | Trigger/cancel; do not lock movement unexpectedly; ownership/licensing of animation is separate. |
| RES-08 | **Voice and dialogue presentation.** Audible and textual expression associated with a resident. | Effect | Voice selection, captions, language, output level, disclosure and permission. | Speak/listen/read/mute; voice selection is not authorization to impersonate a real person. |
