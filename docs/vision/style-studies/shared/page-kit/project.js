// Shared Agentnagar facts for the style showcase pages.
// Sources: README.md, docs/planning/VISION_DECISIONS.md, docs/vision/GUILD_RESIDENTS.md.
// Pages may restyle this text but must not change its facts.
window.AGENTNAGAR = {
  name: 'Agentnagar',
  nameNote: 'Working name; Agentganj and Agent City are the alternatives under consideration.',
  by: 'Super Jackfruit Labs',
  tagline: 'An open maker village that can grow into a city, shared by people and agents.',
  summary: [
    'SJL and independent projects share the world. Residents build homes, and public facilities support learning, recreation and civic simulation.',
    'The first slice is walking the city and watching the fourteen Guild agents at their real work. The public observes; registered users interact according to tier and authority. Comments, messages and assemblies are core.'
  ],
  facts: [
    { label: 'First slice', text: 'Walk the city and watch the 14 Guild agents at their real, current work.' },
    { label: 'Visitors', text: 'The public observes only. Registered users interact according to tier and granted authority.' },
    { label: 'Residency', text: 'A one-time payment buys a block for a home and makes the buyer a resident. Sponsoring the lab is a separate thing.' },
    { label: 'City credits', text: 'Earned in the city, bought, or included with a resident tier. They buy facility access, items, compute and storage. Name pending.' },
    { label: 'Facilities', text: 'The city runs on SJL products: Superpipeline, AgentPod, SuperMD and Supermessage can power its facilities.' },
    { label: 'Privacy', text: 'Personal agents stay private to the person who added them unless shared.' },
    { label: 'Reach', text: 'The product is global.' }
  ],
  status: 'Planning phase: design documents, browser prototypes and a local voxel work-bay experiment. No playable release, hosted city, residency system or live integration yet. Technology choices wait for a clear vision.',
  district: [
    { id: 'R1', name: 'River', note: 'Runs north to south along the west edge.' },
    { id: 'B1', name: 'North bridge', note: 'One low three-span crossing.' },
    { id: 'W1', name: 'Workshop', note: 'Low hall with three sawtooth roof bays; entrance faces east.' },
    { id: 'T1', name: 'Tree Square', note: 'One large living shade tree at the centre of an open square.' },
    { id: 'L1', name: 'Library', note: 'Broad two-storey building with a rounded reading-room roof.' },
    { id: 'S1', name: 'Tram boulevard', note: 'Two ground-level tracks; a cream tram with a coral stripe stops south of the square.' }
  ],
  agentA1: 'City Agent A1 is the recurring guide in every study: the same role, drawn in each style, with a leaf badge.',
  guild: [
    { id: 'onboarding-olivia', name: 'Olivia', role: 'Welcome guide and participation navigator' },
    { id: 'super-chotu', name: 'Super Chotu', role: 'Founding-lab host and project connector' },
    { id: 'project-manager-pete', name: 'Pete', role: 'Project coordinator' },
    { id: 'coder-kai', name: 'Kai', role: 'Workshop engineer and coding tutor' },
    { id: 'artistic-lyra', name: 'Lyra', role: 'Art director and exhibit designer' },
    { id: 'research-ray', name: 'Ray', role: 'Research librarian' },
    { id: 'writer-quill', name: 'Quill', role: 'Story editor and documentation guide' },
    { id: 'analyst-echo', name: 'Echo', role: 'Data interpreter' },
    { id: 'predictor-paul', name: 'Paul', role: 'Scenario modeller' },
    { id: 'strategy-sam', name: 'Sam', role: 'Strategy facilitator' },
    { id: 'controller-casey', name: 'Casey', role: 'Resource and cost adviser' },
    { id: 'optimizer-ollie', name: 'Ollie', role: 'Performance coach' },
    { id: 'threat-hunter-theo', name: 'Theo', role: 'Digital safety educator' },
    { id: 'cleaner-cody', name: 'Cody', role: 'Workspace and reuse steward' }
  ],
  guildNote: 'Proposed public roles; card designs are pending review.',
  // Current roles from the decision register (RD18, 2026-09-24). Styles not listed have none.
  styleRoles: {
    '02-voxel': 'Selected on 2026-09-22 for the first-scene work-bay experiment. Since RD18 (2026-09-24) the city is built to work in any style; Voxel is the third style pack in the Godot city client, added after low-poly and pixel art.',
    '08-pixel-art': 'Since RD18 (2026-09-24), one of the two styles used to prove that the city\u2019s mechanics work in any style: a style pack in the Godot city client, drawn as true 2D sprites.',
    '11-low-poly-tropical-diorama': 'Since RD18 (2026-09-24), one of the two styles used to prove that the city\u2019s mechanics work in any style: a style pack in the Godot city client.'
  },
  // The generator follows this page's own sheets (styles-data.js records which carry
  // OpenAI's C2PA credentials); the index names none.
  conceptNote: (() => {
    const id = document.documentElement.getAttribute('data-style');
    const style = ((window.STYLE_DATA || {}).styles || []).find((s) => s.id === id);
    const generator = style ? ` (${style.generator_note})` : '';
    return `AI-generated concept illustrations${generator} for design exploration, released under CC0 1.0; not game captures or implementation evidence. Selection does not imply review approval.`;
  })()
};
