# Sample station

Sample station is what every workstation opens when nobody is signed in. It
is **synthetic**: every file here was written for the purpose, by hand or by
the script in `tools/`. None of it was recorded from a real station, shell,
node, board or person, and it holds no real station's data. The names
"Sample agent", "sample-node", "Sample board", the `tally` project and every
ID, hash, time and number are invented.

`core/station/sample_source.gd` plays it behind the same `StationSource`
interface as the live source, so the station computer's apps never branch on
where their data comes from. Each file uses the wire shapes of the route it
stands in for, field for field, as the protocol reference gives them
(AgentPod `9bc1997`, Superpipeline `d53992f`).

| File | Stands in for |
| --- | --- |
| `station.json` | `GET /api/fleet/agents`: `{stats, agents: [FleetAgent]}` |
| `health.json` | a series of `StationHealth` bodies from `GET /api/stations/:id/health`, one per refresh |
| `files.json` | `GET /api/stations/:id/files?path=…`: each key is a listing's `path`, each value its `FsEntry[]` |
| `files/` | the bodies `GET /api/stations/:id/file` returns; only paths listed in `files.json` are read |
| `logs.txt` | the log tail's `data:` lines |
| `changeset.json` | `POST /api/stations/:id/changeset/status`: a `ChangesetStatus` |
| `diff.patch` | `POST /api/stations/:id/changeset/diff`: each file's section belongs to the side whose file list names it |
| `terminal.cast` | the terminal's output, as asciicast v2 |
| `chat.json` | one ACP console session (§5a) |
| `work.json` | Superpipeline's boards, agents, board snapshot and card activities (§7, §8) |

## The terminal

`terminal.cast` is written by `tools/make_terminal_cast.py`, never captured
from a shell, which would carry the machine's real paths, user and
environment. It builds and tests `tally`: one test fails, a patch fixes it,
and the tests pass. Each command is preceded by an asciicast `m` marker. The
player plays the lines before the first marker when the terminal opens, and
then one command, from its marker to the next, each time the player presses
Enter. Gaps longer than 3 s are cut to 3 s.

After editing the script, run `python3 tools/make_terminal_cast.py`; with
`--check` it fails when `terminal.cast` is out of date.

## The chat

`chat.json` holds the session row, its recorded events (each a complete
`AcpEvent`), and steps the player plays later:

- `continuations.allow` after the permission request is answered with an
  `allow_*` option, and `continuations.reject` after a `reject_*` one;
- `reply` after any new prompt, since a recording cannot answer one.

A step is `{after, type, payload}`: `after` is its delay in seconds, and the
player gives it the session's next `seq` and the current time, as the hub
does. The player writes the `permission-answer`, `user-prompt` and `state`
events itself, where the hub would.

## Work

`work.json` holds `GET /v1/boards`, `GET /v1/agents`, the board's snapshot and
each card's activities. `station_links` is Sample station's built-in answer to
"Which Superpipeline agent works at this station?". `after_answer` lists the
activities the agent posts once its question is answered, played as new
activities.

Resolving the gate or answering the question changes the board as
Superpipeline's board does and plays the events it would send. As on the real
board, a card waiting at a gated human stage has no `delegateAgentId`: the
agent that did the work is the gate's `producedBy`.
