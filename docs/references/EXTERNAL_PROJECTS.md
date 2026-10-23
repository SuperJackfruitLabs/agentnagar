# External projects to evaluate

Open-source projects that could help Agentnagar's Godot city and its Blender
asset pipeline. Each entry was checked on 2026-10-23 against its GitHub
repository: licence, last activity, and how it relates to what this
repository already uses. Nothing here has been installed or run, and a
listing does not mean a project has been adopted. Adopting any of them still
goes through the planning gates and [tool strategy](../architecture/TOOLS.md).

The city prototype targets Godot 4.6 (`city/godot/project.godot`). Several of
these were already studied in the 2026-10-01 research
[Building 3D worlds with AI agents](../research/2026-10-01-building-3d-worlds-with-ai-agents/README.md); where it applies,
this page links that research instead of repeating it.

## Godot add-ons

| Project | Licence | What it offers | Fit and caveats |
| --- | --- | --- | --- |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | MIT | Editable terrain: sculpting, texture painting, foliage, level of detail | For hills, shores and open ground beyond the street grid. v1.0.2 (2026-05-19) supports Godot 4.4–4.6+; its web export is very experimental ([research note](../research/2026-10-01-building-3d-worlds-with-ai-agents/notes/godot-agent-tooling.md)) |
| [LimboAI](https://github.com/limbonaut/limboai) | MIT | Behaviour trees and state machines, with an editor and debugger | Candidate for resident and visitor movement around the live agents. Its README lists Godot 4.2–4.7; latest v1.8.1 (2026-08-20) |
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | MIT | Cinemachine-style cameras: follow, framing, smooth transitions | For the walk-the-city camera and for framing agents at work. Godot 4.4+; latest v0.11.0.3 (2026-07-19). Already in the reuse map of the [transit research](../research/2026-10-01-building-3d-worlds-with-ai-agents/notes/cities-skylines-and-transit-systems.md) |
| [Dialogic](https://github.com/dialogic-godot/dialogic) | MIT | Branching dialogue, characters, timelines | Suits authored scenes only, such as onboarding or tutorials. Live agent conversation does not go through a scripted dialogue tree. Dialogic 2 is still alpha (2.0-alpha-20) |
| [Godot demo projects](https://github.com/godotengine/godot-demo-projects) | MIT | Official working examples: 3D, networking, rendering | Copy patterns from here before writing a system from scratch |
| [Godot Jolt](https://github.com/godot-jolt/godot-jolt) | MIT | Jolt physics as an extension | **Not needed.** Since Godot 4.4, Jolt is built in as an engine module, and the extension is in maintenance mode. Godot 4.6 makes Jolt the default for new 3D projects |

[Godot](https://github.com/godotengine/godot) itself is already the
prototype's engine. [meshoptimizer](https://github.com/zeux/meshoptimizer) is
already bundled inside Godot (see `city/packaging/licenses/godot/COPYRIGHT.txt`).
Its `gltfpack` tool becomes useful only if exported glTF files need shrinking
before import.

## Blender and animation

| Project | Licence | What it offers | Fit and caveats |
| --- | --- | --- | --- |
| [MCP for Blender](https://github.com/ahujasid/mcp-for-blender) | MIT | Lets an agent drive Blender in an open session | Already evaluated in [tool automation](../research/TOOL_AUTOMATION.md) under its old name, `ahujasid/blender-mcp`, and in the [asset-kit research](../research/2026-10-01-building-3d-worlds-with-ai-agents/notes/asset-kits-and-kitbashing.md). That finding still holds: it is an interactive add-on, not a headless service, so repeatable bakes stay in batch scripts |
| [DSH Blender plugin](https://github.com/sixtysevenlf/dsh-blender-plugin) | BSD-3-Clause | 15 modelling tools for AI-driven Blender, with a pause switch | Works only through DSH, a separate product, so it ties the pipeline to that service. Prefer MCP for Blender or batch scripts |
| [Motion2MixamoRig](https://github.com/MaxLiu22/Motion2MixamoRig) | Apache-2.0 (code) | Moves the motion of one person in a video onto a Mixamo-rigged character; outputs a skinned `.glb` | **Blocked twice.** It requires the SMPL-X body model, whose licence covers non-commercial research only, so commercial use needs a separate licence. It also targets Mixamo rigs, which the [character animation research](../research/2026-10-01-building-3d-worlds-with-ai-agents/notes/character-animation-and-movement.md) already excluded because Mixamo files may not be distributed. Use that note's CC0 options instead, such as Mesh2Motion and the Quaternius libraries. Experimental (v0.1.7) |

## Process

| Project | Licence | What it offers | Fit and caveats |
| --- | --- | --- | --- |
| [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) | MIT | 49 agents and 74 skills arranged as a studio hierarchy, with design reviews and QA passes | Worth reading for its review checklists and design-document templates. Adopting the whole hierarchy would duplicate the planning gates and Superpipeline review flow this project already has |
