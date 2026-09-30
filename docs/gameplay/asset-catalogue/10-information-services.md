# Information and services

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

These are spatial interfaces to content or capabilities. Access checks belong to the owning service; an attractive facade, purchased kiosk or physical presence is not authorization.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| INFO-01 | **Wayfinding sign and address marker.** Readable navigation and place identity. | Fixed | Destination ID, text/icon, language, orientation, contrast and map association. | Read/inspect route; update by authorized editor. |
| INFO-02 | **Notice and community board.** Surface for approved announcements and discussion entry points. | Fixed | Post slots, content references, expiry, author identity and visibility. | Browse/post with grants; moderation and comment rights remain separate. |
| INFO-03 | **Project and work-status board.** Approved projection of project progress or Guild activity. | Fixed | Source authority, public fields, freshness timestamp, redaction and offline state. | Observe/inspect; stale data clearly marked; no private task details inferred. |
| INFO-04 | **Facility kiosk.** Contextual access to browsing, booking and asking for help. | Fixed | Service identity, touch/input zones, accessible alternative, session and actions. | Browse/book/ask according to account and service grants. |
| INFO-05 | **Shop display and sale label.** Shows the specific goods and terms offered for sale. | Fixed | Item instance reference, seller, price, included contents, availability and destination. | Inspect/purchase through trade flow; label is not the coin ledger. |
| INFO-06 | **Mailbox and collection locker.** Private delivery endpoint for messages or permitted goods. | Fixed | Recipient, compartments, capacity, delivery grants and notification preference. | Deposit/collect under grants; mail content and parcel ownership kept distinct. |
| INFO-07 | **Map stand and city directory.** Place-based overview of routes and facilities. | Fixed | Map extent, landmark IDs, search/filter, route options and accessibility. | Browse/navigate; directory symbols reference the same city identities. |
| INFO-08 | **Exhibit screen and interactive demonstration.** Publicly approved explanation or bounded demonstration. | Fixed | Source/version, audience, permitted controls, reset behavior and availability. | Observe/try if authorized; demonstration actions do not imply live production access. |
| INFO-09 | **Interaction marker and selection feedback.** Accessible presentation of an available action. | Effect | Target ID, action name, focus state, input hints and non-color alternatives. | Show/hide/select; adapt to touch/controller/keyboard and future spatial input. |
