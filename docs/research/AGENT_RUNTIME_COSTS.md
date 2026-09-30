# Agent runtime costs

Desk research and cost model · 2026-09-18 · [Plan index](../README.md)

This brief prices what the [2026-09-18 decisions](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
imply: public observation of the Guild at work (RD01, RD03), registered-user
interaction by tier (RD04), credits that buy real compute and storage
(RD07, RD08) and private personal agents (RD12). It gives options, numbers
and sensitivities. It does not choose a model, host or vendor (RD15).

**Evidence limits.** Every price below was fetched from the named vendor page
on 2026-09-18 and will change; several vendors changed prices in the last
three months. Nothing was measured on SJL's own stack: no Hermes session,
no lab-server benchmark, no API call was made for this brief. Token counts per
turn, turns per conversation, tool-call counts, cache hit rates and usage
rates are **assumptions**, labelled as such, chosen to be redone with the
formulas given. Pages rendered by JavaScript (Hetzner, Azure Speech, AWS S3
tables) did not yield numbers and are marked "not verified". OpenAI's Usage
Policies page could not be fetched at all (HTTP 403 on the live page and on
the archive copy); OpenAI's Terms of Use and Services Agreement were read
from Internet Archive captures of 2026-09-15/16. Legal clauses are quoted
verbatim from fetched pages; anything called "reading" is our
interpretation, not legal advice.

## 1. What costs what, per access level

| Access level (decision) | What actually runs | Marginal cost driver | Order of magnitude |
| --- | --- | --- | --- |
| (a) Public observes agents at work (RD01, RD03) | Status projection from the Hermes/AgentPod adapter; fan-out over WebSocket/SSE; optional LLM rewrite of work state into public-safe text | Zero model cost if templated. With a small-model summary per agent per state change: 14 × 6/h × 24 h ≈ 2,000 calls/day | $0.5–$5 per day (§3.4); fan-out is bandwidth, not tokens |
| (b) Registered user chats with a Guild agent (RD04) | One persona system prompt + growing history, re-sent every turn | System prompt size, turns per conversation, cache hit rate | $0.01–$0.11 per 8-turn conversation by tier (§3.1) |
| (c) Registered/resident asks for a task (RD04, RD08) | Agentic loop with tools; context grows with every tool result | Tool steps N and result size R; cost grows roughly with N² | $0.13–$0.95 per 25-step task; $0.6–$3.1 at 60 steps (§3.2) |
| (d) NPC / simulated-citizen dialogue | Scripted lines (free), or a 1–8B model locally or via a cheap host | Barks per hour; local CPU capacity | $0 scripted; ~$0.0001 per bark hosted; local capacity ~700–900 short outputs/h on the lab server (§4) |
| (e) Optional voice | TTS per character; cacheable for repeated lines | Characters synthesised, voice tier, cache hit rate | $0.004–$0.10 per 1,000 characters (§7) |
| (f) Resident's personal agent hosted by the city (RD12) | A container or sandbox plus tokens on the resident's key or credits | Idle hours if always-on; tokens as (b)/(c) | $20–$140 per month always-on; near zero if scaled to zero (§8) |

Two structural points follow. First, the observation slice (RD01) is cheap
because the Guild's work already exists; the city pays for a projection,
not for inference. Second, once a registered user can make an agent do
work (c), cost is no longer bounded by the conversation but by the tool
loop, so the controls in §6 are a cost-model requirement, not a nicety.

## 2. Price table, 2026-09-18

Prices are USD per million tokens (MTok), standard tier, global routing.
"Cache read" is the price of a cached input token; "write" the price to
create the cache entry. Batch = asynchronous discount on both input and
output where offered. All fetched from the official pricing pages listed in
Sources on 2026-09-18.

### Anthropic (Claude API)

| Model | Input | Cache write 5 m / 1 h | Cache read | Output | Batch |
| --- | --- | --- | --- | --- | --- |
| Claude Fable 5.1 | 10.00 | 12.50 / 20.00 | 0.25 (0.025×) | 50.00 | 50% |
| Claude Fable 5 | 10.00 | 12.50 / 20.00 | 1.00 | 50.00 | 50% |
| Claude Opus 5 / 4.8 / 4.7 / 4.6 / 4.5 | 5.00 | 6.25 / 10.00 | 0.50 | 25.00 | 50% |
| Claude Sonnet 5 | 2.00 | 2.50 / 4.00 | 0.20 | 10.00 | 50% |
| Claude Sonnet 4.6 / 4.5 | 3.00 | 3.75 / 6.00 | 0.30 | 15.00 | 50% |
| Claude Haiku 4.5 | 1.00 | 1.25 / 2.00 | 0.10 | 5.00 | 50% |

Notes from the same page: Sonnet 5's $2/$10 "introductory" price is now the
standard price (the planned rise to $3/$15 on 2026-09-01 "will not occur").
Claude 4.7 and later use a tokenizer that "produces approximately 30% more
tokens for the same text", so token counts from older models do not carry
over. The full 1M context is billed at the standard rate. US-only
`inference_geo` costs 1.1×. Web search is $10 per 1,000 searches; web fetch
and client-side tools cost only tokens. Managed Agents add $0.08 per
session-hour of `running` time. Tool use adds a hidden system prompt of
roughly 290–500 tokens per request depending on model, plus 325 tokens for
the bash tool and 700 for the text editor.

### OpenAI (API)

| Model | Input | Cached input | Output | Batch |
| --- | --- | --- | --- | --- |
| GPT-6 Astra | 10.00 | 1.00 | 50.00 | 50% |
| GPT-5.6 Sol | 4.00 | 0.40 | 20.00 | 50% |
| GPT-5.6 Terra | 2.00 | 0.20 | 12.00 | 50% |
| GPT-5.6 Luna | 0.20 | 0.02 | 1.20 | 50% |
| GPT-5 | 1.25 | 0.125 | 10.00 | 50% |
| GPT-5-mini | 0.25 | 0.025 | 2.00 | 50% |
| GPT-5-nano | 0.05 | 0.005 | 0.40 | 50% |

Cached input is 0.1× on current models. A "fast" tier costs 2× standard.
Code Interpreter containers are $0.03–$1.92 per 20-minute session by RAM.
Web search is $10 per 1,000 calls plus content tokens.

### Google (Gemini API, paid tier)

| Model | Input | Cache read | Output | Cache storage | Batch |
| --- | --- | --- | --- | --- | --- |
| Gemini 3.1 Pro Preview (≤200k) | 2.00 | 0.20 | 12.00 | 4.50 /MTok/h | 50% |
| Gemini 3.8 Flash (promo to 2026-12-31) | 0.75 | 0.075 | 3.75 | 0.50 /MTok/h | 50% |
| Gemini 3.5 Flash | 1.50 | 0.15 | 9.00 | 1.00 /MTok/h | 50% |
| Gemini 3.5 Flash-Lite | 0.30 | 0.03 | 2.50 | 1.00 /MTok/h | 50% |
| Gemini 2.5 Flash-Lite | 0.10 | — | 0.40 | — | 50% |

Gemini context caching charges an hourly storage fee on top of the read
discount, which matters for a persona kept warm all day: 6,000 cached
tokens × $1.00/MTok/h × 730 h ≈ $4.40 per persona-month on 3.5 Flash. Free
tier content is "used to improve our products"; paid tier content is not.

### Open-weight models via hosted inference

| Host and model | Input | Cached | Output | Notes |
| --- | --- | --- | --- | --- |
| Groq · gpt-oss-120B | 0.15 | — | 0.60 | ~500 tok/s quoted; 131k context |
| Groq · gpt-oss-20B | 0.075 | — | 0.30 | ~1,000 tok/s quoted; cheapest self-serve |
| Groq · Llama 3.1 8B / 3.3 70B | enterprise | — | enterprise | No published per-token price on the models page |
| Together · gpt-oss-120B | 0.15 | — | 0.60 | Batch discount offered |
| Together · Qwen3.5 9B | 0.17 | — | 0.25 | |
| Together · GLM-5.3-Flash | 0.15 | — | 0.50 | |
| Together · DeepSeek V4 Pro | 1.32 | — | 3.96 | |
| Fireworks · <4B / 4–16B / >16B params | 0.10 / 0.20 / 0.90 | 10% of input | same | Batch 50% |
| Fireworks · DeepSeek V4.1 Flash | 0.22 | 0.007 | 0.66 | |
| DeepSeek · deepseek-flash (peak / off-peak) | 0.30 / 0.15 | 0.006 / 0.003 | 1.20 / 0.60 | Off-peak = all hours except 01–04 and 06–10 UTC weekdays |
| OpenRouter | pass-through | | | No markup on inference; 5.5% ($0.80 min) on card credit purchases, 5% crypto |

Cerebras's pricing page did not render its tables in two fetches; not
verified today.

### Prompt caching mechanics and what a persona saves

Anthropic caches an exact prefix (tools → system → messages); any byte
change earlier in the prefix invalidates everything after it. Writes cost
1.25× (5-minute TTL) or 2× (1-hour TTL); reads cost 0.1× (0.025× on Fable
5.1). A read refreshes the timer, so a persona that receives a request at
least every five minutes stays warm on the cheaper TTL. Minimum cacheable
prefix is model-dependent (512–4,096 tokens), so a 1,000-token persona may
silently not cache on some models. OpenAI and Gemini use automatic prefix
caching at 0.1×; Gemini adds the hourly storage fee above.

For a Guild persona with a stable 6,000-token system prompt, the model in
§3 shows caching cuts an 8-turn conversation by 67% and a 25-step task by
77%, because the growing history is re-read at 0.1× rather than re-billed
in full. The saving disappears if the prompt carries a timestamp, a live
status line or per-user text ahead of the cache breakpoint; put volatile
content after it.

## 3. Parametric cost model

### Variables

| Symbol | Meaning | Default (assumption) |
| --- | --- | --- |
| `S` | Persona system prompt + tool definitions, tokens | 6,000 chat; 10,000 task |
| `T` | Turns per conversation | 8 |
| `U` | User tokens per turn | 60 |
| `A` | Assistant output tokens per turn or per tool step | 200 chat; 300 task |
| `N` | Tool steps per agentic task (the "tool-call multiplier") | 25 (heavy: 60) |
| `R` | Tokens returned per tool result | 1,500 |
| `F` | Final answer tokens for a task | 1,000 |
| `h` | Cache hit rate on the cached prefix | 1.0 (sensitivity below) |
| `p_in, p_w, p_r, p_out` | Prices per token: input, cache write, cache read, output | from §2 |
| `DAU` | Daily active registered users | 30% of registered |
| `c` | Conversations per DAU per day | 2 |
| `t` | Tasks per DAU per day | 0.2 |

Tiers used: **open** = gpt-oss-120B at $0.15/$0.60 with no cache
discount; **small** = Claude Haiku 4.5; **mid** = Claude Sonnet 5;
**frontier** = Claude Opus 5. Fable 5.1 would be 2× frontier on input and
output.

### Formulas

```
Conversation (turn k = 1..T; history H_k = (k-1)(U+A)):
  turn 1:  S·p_w + U·p_w + A·p_out
  turn k:  (S+H_k)·(h·p_r + (1-h)·p_in) + U·p_w + A·p_out
  uncached: (S+H_k+U)·p_in + A·p_out         per turn
  C_conv = Σ_k turn_k

Agentic task (step k = 1..N; context X_k = (k-1)(R+A)):
  step 1:  S·p_w + A·p_out + (R+A)·p_w
  step k:  (S+X_k)·(h·p_r + (1-h)·p_in) + A·p_out + (R+A)·p_w
  final:   F·p_out
  C_task = Σ_k step_k + final
  Uncached input volume ≈ N·S + (R+A)·N(N+1)/2   (quadratic in N)

Summariser:  C_sum = S·p_r + state·p_in + out·p_out   per state change
  daily = agents × changes_per_hour × 24 × C_sum

Monthly:  M = DAU × 30 × (c·C_conv + t·C_task) + 30·daily_summariser
Credits:  price = cost / (1 - g)   for target gross margin g
```

The script that produced the tables (`costmodel.py`) is a throwaway in the
research scratch directory; the formulas above are sufficient to redo it.
The mid-tier conversation figure was also checked by hand, turn by turn.

### 3.1 Cost per conversation (S=6,000, T=8, U=60, A=200)

| Tier | Cached | Uncached | Saving |
| --- | --- | --- | --- |
| open | $0.009 | $0.009 | — |
| small | $0.021 | $0.064 | 67% |
| mid | $0.042 | $0.128 | 67% |
| frontier | $0.105 | $0.319 | 67% |

### 3.2 Cost per agentic task (S=10,000, N=25, R=1,500, A=300, F=1,000)

| Tier | Cached, N=25 | Uncached, N=25 | Cached, N=60 | Uncached, N=60 |
| --- | --- | --- | --- | --- |
| open | $0.12 | $0.12 | $0.58 | $0.58 |
| small | $0.19 | $0.83 | $0.62 | $3.88 |
| mid | $0.38 | $1.67 | $1.24 | $7.76 |
| frontier | $0.95 | $4.16 | $3.10 | $19.41 |

A task is 5–10× a conversation and, at 60 steps, 30× on the same tier. The
uncached column is what a harness that rebuilds its prompt every step pays;
this is the single largest avoidable cost in the model.

### 3.3 Three usage scenarios, per month

DAU = 30% of registered; 2 conversations and 0.2 tasks per DAU per day;
caching on. Excludes the summariser, voice and hosting.

| Scenario | Registered | DAU | open | small | mid | frontier | per DAU-month (mid) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Quiet | 20 | 6 | $8 | $14 | $29 | $72 | $4.79 |
| Modest | 200 | 60 | $80 | $144 | $288 | $719 | $4.79 |
| Lively | 2,000 | 600 | $805 | $1,438 | $2,877 | $7,192 | $4.79 |

Per DAU-month by tier: open $1.34, small $2.40, mid $4.79, frontier $11.99.
The model is linear in DAU, so these are the numbers to attach to a tier
price: a resident tier that includes this usage on the mid tier costs SJL
roughly $5 per active resident per month before margin, and roughly $1.60
if the average resident is active only every third day.

### 3.4 Public-observation summariser (RD01)

14 agents × 6 state changes per hour × 24 h = 2,016 summaries per day,
each 800 cached system tokens + 700 tokens of state in, 80 tokens out.

| Tier | Per summary | Per day | Per month | Batch (50%) |
| --- | --- | --- | --- | --- |
| open | $0.0003 | $0.55 | $17 | $8 |
| small | $0.0012 | $2.38 | $71 | $36 |
| mid | $0.0024 | $4.76 | $143 | $71 |
| frontier | $0.0059 | $11.89 | $357 | $178 |

Templated status ("Kai: editing `apps/hub`, 3 files changed, last commit
2 min ago") costs nothing and is also the more honest projection per
[AGENT_CITY](../gameplay/AGENT_CITY.md#honest-presence). A summariser is
only worth paying for where raw state must be redacted into prose; then
cache the summary per (agent, state hash) so identical states are never
re-summarised, and rate-limit to one call per agent per few minutes. Note
that the Batch API is not suitable for a live feed (results arrive
asynchronously); the batch column is for a nightly digest.

### 3.5 Inversion: what $1 of credits buys, and a sustainable credit price

| Tier | Conversations per $1 | 25-step tasks per $1 |
| --- | --- | --- |
| open | 107 | 7.7 |
| small | 48 | 5.3 |
| mid | 24 | 2.6 |
| frontier | 9.5 | 1.1 |

If one credit is pegged at $0.01 of purchase price, the price of a mid-tier
conversation and task at three gross-margin targets is:

| Gross margin g | Conversation | 25-step task |
| --- | --- | --- |
| 30% | $0.060 = 6 credits | $0.54 = 54 credits |
| 50% | $0.084 = 8 credits | $0.76 = 76 credits |
| 65% | $0.120 = 12 credits | $1.08 = 108 credits |

What the margin has to cover before it is profit: card fees (a 5.5% +
fixed-fee benchmark from OpenRouter's own credit surcharge; Stripe-type
fees are similar), refunds and chargebacks (§6), the uncached fraction the
model does not predict, idle hosting, and the earned-credit pool (RD07):
every credit earned in play and spent on real compute is a cost with no
purchase behind it, so earned credits need either a separate budget line
or a lower conversion rate into compute. A margin below ~50% on token
resale leaves little room for these; well-known API resellers sit at 2–3×
raw token cost. Better than a flat markup: bill tasks against a reserved
ceiling and settle at actual usage (§6), so the margin does not have to
absorb variance in N.

### 3.6 Sensitivity: the variables that dominate

**System prompt size and turns (mid tier, cached, per conversation):**

| S \ T | 4 | 8 | 16 | 30 |
| --- | --- | --- | --- | --- |
| 2,000 | $0.015 | $0.027 | $0.052 | $0.104 |
| 6,000 | $0.028 | $0.042 | $0.074 | $0.137 |
| 15,000 | $0.055 | $0.077 | $0.123 | $0.212 |
| 30,000 | $0.102 | $0.136 | $0.206 | $0.336 |

**Tool steps and result size (mid tier, cached, per task):**

| R \ N | 10 | 25 | 60 | 120 |
| --- | --- | --- | --- | --- |
| 500 | $0.11 | $0.26 | $0.74 | $2.02 |
| 1,500 | $0.14 | $0.38 | $1.24 | $3.74 |
| 4,000 | $0.23 | $0.69 | $2.50 | $8.06 |

**Cache hit rate (mid tier):** h = 1.0 → conv $0.042 / task $0.38;
h = 0.8 → $0.060 / $0.66; h = 0.5 → $0.086 / $1.08; h = 0 → $0.131 / $1.78.

Reading: for chat, prompt size dominates and turns matter less than one
would expect; for tasks, the step count N dominates because the whole
context is re-read every step, and a 20-point drop in cache hit rate costs
more than doubling the persona. Output tokens are a minority of cost in
every scenario above, so "make the agent terser" saves little; "make the
agent take fewer steps and return smaller tool results" saves a lot.

## 4. Local inference on a CPU-only lab server

Assume a CPU-only server in the class of a mid-range desktop CPU with
dual-channel DDR4 and no GPU, as for the candidate lab server
([MULTIPLAYER](../architecture/MULTIPLAYER.md#what-was-checked-on-the-lab-server)).
Token generation on a CPU is bound by memory bandwidth, not cores: each
generated token streams the whole quantised model through RAM once.

```
tok/s (single stream) ≈ achieved_bandwidth_GB/s ÷ model_size_GB
mid-range desktop CPU, dual-channel DDR4: 40–50 GB/s peak, ~30 GB/s achieved
  1B Q4 (~0.8 GB) ≈ 38–64 tok/s     3B Q4 (~2 GB) ≈ 15–25 tok/s
  8B Q4_K_M (~4.9 GB) ≈ 6–10 tok/s
```

Published CPU-only measurements fit this band: a Ryzen 5 5600X (6 cores,
DDR4-3000) generates 8.95 tok/s on Mistral-7B Q4_0 with 23.9 tok/s prompt
processing; a Ryzen 9 5950X (16 cores, DDR4-3600) manages only 8.5 tok/s on
the same class of model, showing that cores do not help generation; a
64-core EPYC 7H12 reaches 7.0 tok/s generation but 250 tok/s prompt
processing (llamafile discussion #450). A modern Ryzen 9 7950X on DDR5-6000
reaches 26.4 tok/s on Qwen3-8B Q4_K_M with 210 tok/s prompt processing and
about 1.25 s time to first token for a 512-token prompt (markaicode, build
b9838, 2026-06). Llama 3.2 3B runs at 23–24 tok/s on a Ryzen AI 5 laptop
and 5 tok/s on a Raspberry Pi 5 (geerlingguy/ai-benchmarks).

Concurrency: `llama-server` supports `--parallel` slots with continuous
batching on by default, but on a CPU the slots share the same bandwidth,
so aggregate throughput rises only modestly and per-stream speed falls.
Treat the lab server as roughly one 8B stream or two to three 3B streams at once.
A 70B Q4 model (~40 GB) loads only where there is that much free RAM, and
at ~1 tok/s it is not useful interactively.

| Use | Fit on the lab server (assumption from the figures above) |
| --- | --- |
| NPC barks, 20–40 output tokens, 1–3B model | Yes: ~700–900 per hour if the worker is dedicated; pre-generate and cache the common ones instead |
| Status summaries, 80 tokens, 3B model | Yes for a few hundred per hour; not for a burst when all 14 agents change state at once |
| Moderation pre-filter (classify, 1–5 output tokens) | Yes: prompt processing at 20–60 tok/s on such a CPU is the limit, so keep inputs under ~300 tokens |
| Registered-user chat with a persona | No: 6–10 tok/s and 1–3 s to first token on an 8B model, and one user at a time |
| Agentic tasks | No |

Each local worker also competes with the room server and asset jobs for
the same 12 threads (MULTIPLAYER's proposed 2-thread room reservation).

**Renting a GPU instead.** Hourly prices fetched 2026-09-18:

| Provider | GPU | Price per hour |
| --- | --- | --- |
| RunPod (community / secure) | RTX 4090 24 GB | $0.34 / $0.74 |
| RunPod (community / secure) | RTX 5090 32 GB | $0.69 / $0.99 |
| RunPod (community / secure) | L40S 48 GB | $0.79 / $1.09 |
| RunPod (community / secure) | A100 80 GB PCIe | $1.19 / $1.59 |
| RunPod (community / secure) | H100 SXM | $2.69 / $3.49 |
| Lambda (on-demand, 1×) | A10 24 GB / A100 40 GB / H100 PCIe / H100 SXM | $1.29 / $1.99 / $3.29 / $4.29 |
| Together (dedicated) | H100 / H200 / B200 | $3.99–5.49 / contact / $8.99 |
| Modal (per-second) | T4 / L4 / A10 / A100 40 GB / H100 | $0.59 / $0.80 / $1.10 / $2.10 / $3.95 |
| Fireworks (on-demand) | H100 / H200 / B200 | $8.00 / $8.00 / $13.00 |

Break-even against a hosted open model at $0.60/MTok output: a secure
RTX 4090 at $0.74/h serving an 8B model must sustain roughly 1,200 tok/s
aggregate (an assumed vLLM figure at high concurrency) to reach
$0.17/MTok; at 20% utilisation the same box costs $0.86/MTok, above the
API price. The general rule:

```
GPU $/MTok = hourly_price ÷ (aggregate_tok/s × 3600 ÷ 1e6) ÷ utilisation
```

Below a few hundred concurrent users, per-token hosted inference beats a
rented GPU unless the GPU also does something else (TTS, embeddings,
asset jobs) or must exist for privacy reasons. Vast.ai and interruptible
tiers are cheaper still but were not verified today.

## 5. Subscription-backed harnesses versus the API

The 14 Guild agents run on the Hermes harness. What follows is what each
provider's current terms say about (i) powering a public or multi-user
service from a consumer subscription, (ii) reselling or passing through
inference, and (iii) persona'd public deployments and disclosure. Quoted
text is verbatim from pages fetched 2026-09-18.

### Anthropic

Facts (quoted):

- Consumer Terms (effective 2025-10-08), section 2: "You may not share
  your Account login information, Anthropic API key, or Account
  credentials with anyone else. You also may not make your Account
  available to anyone else." Section 3 prohibits, "Except when you are
  accessing our Services via an Anthropic API Key or where we otherwise
  explicitly permit it, to access the Services through automated or
  non-human means, whether through a bot, script, or otherwise", and "To
  develop any products or services that compete with our Services,
  including to develop or train any artificial intelligence or machine
  learning algorithms or models or resell the Services."
- Claude Code legal page: "OAuth authentication is intended exclusively
  for purchasers of Claude Free, Pro, Max, Team, and Enterprise
  subscription plans and is designed to support ordinary use of Claude
  Code and other native Anthropic applications." "Developers building
  products or services that interact with Claude's capabilities, including
  those using the Agent SDK, should use API key authentication ...
  Anthropic does not permit third-party developers to offer Claude.ai
  login into their own applications, or to route requests through Free,
  Pro, or Max plan credentials on behalf of their users." Also:
  "Customers may not pay for, resell, or intermediate Claude usage on
  their end users' behalf", and "Advertised usage limits for Pro and Max
  plans assume ordinary, individual usage of Claude Code and the Agent
  SDK."
- Commercial Terms (effective 2025-06-17), A.1: "Anthropic gives Customer
  permission to use the Services, including to power products and
  services Customer makes available to its own customers and end users".
  D.4: "Customer may not and must not attempt to (a) access the Services
  to build a competing product or service, including to train competing
  AI models or resell the Services except as expressly approved by
  Anthropic".
- Usage Policy (effective 2025-09-15) applies to "anyone who can submit
  inputs to Anthropic's products and/or services, including via any
  authorized resellers or passthrough access". "All consumer-facing
  chatbots, including any external-facing or interactive AI agent, must
  disclose to users that they are interacting with AI rather than a
  human. This disclosure must be provided at a minimum at the beginning
  of each chat session." Prohibited: "Impersonate a human by presenting
  results as human-generated, or using results in a manner intended to
  convince a natural person that they are communicating with a natural
  person when they are not." "Products serving minors ... must comply
  with the additional guidelines outlined in our Help Center article."

Our reading: the observation slice (RD01/RD03) does not by itself change
how the Guild agents are billed, because the public submits no input to
any model; it is a projection of work SJL already does under whatever
plan it holds. The moment a registered user can send a message that
reaches a model (RD04), the city is a product "made available to end
users", which the Commercial Terms permit on an API key and the consumer
terms and the Claude Code legal page do not permit on Pro/Max
credentials. A third-party harness such as Hermes running on a
subscription token is, on the Claude Code page's wording, outside
"ordinary, individual usage"; whether Anthropic treats a solo founder's
own agents that way is not stated and should be asked. Every persona
needs an AI badge at the start of each session (already proposed in
AGENT_CITY), and the age scope left open under RD05 interacts with the
minors guideline.

### OpenAI

Facts (quoted from Internet Archive captures of 2026-09-15/16):

- Terms of Use (effective 2026-01-01): "You may not share your account
  credentials or make your account available to anyone else"; you may not
  "Modify, copy, lease, sell or distribute any of our Services",
  "Automatically or programmatically extract data or Output", "Represent
  that Output was human-generated when it was not", or "Interfere with or
  disrupt our Services, including circumvent any rate limits or
  restrictions".
- Services Agreement (effective 2026-01-01; applies to APIs, ChatGPT
  Enterprise/Business): 2.2 grants "the right to use OpenAI's API to
  integrate the Services into Customer Applications and to make Customer
  Applications available to End Users." 3.1: "Customer may not resell or
  lease access to its Account or any End User Account." 3.3 (g): Customer
  will not "buy, sell, or transfer API keys from, to, or with a third
  party"; (i): nor "violate or circumvent Usage Limits or otherwise
  configure the Services to avoid Usage Limits."
- Codex authentication docs: "Use API key authentication for programmatic
  Codex CLI workflows, such as CI/CD jobs" and "Don't expose Codex
  execution in untrusted or public environments."

Not verified: OpenAI's Usage Policies page (403 on the live site and on
the archive). Third-party summaries say developers must disclose AI use,
but no primary text was obtained. Our reading: same shape as Anthropic;
a ChatGPT-plan Codex sign-in is for the individual's own workflows, and a
service that lets users drive the model needs the API under the Services
Agreement.

### Google

Facts (quoted):

- Gemini CLI terms page: "Directly accessing the services powering Gemini
  CLI (for example, the Gemini Code Assist service) using third-party
  software, tools, or services (for example, using OpenClaw with Gemini
  CLI OAuth) is a violation of applicable terms and policies." The
  supported route for a third-party coding agent is an API key. Third-party
  reporting says individual Google AI Pro/Ultra tiers stopped being served
  by the Code Assist extensions and CLI from 2026-06-18; not verified on a
  Google page.
- Gemini API Additional Terms (effective 2026-03-23): "You must be 18
  years of age or older to use the APIs. You also will not use the
  Services as part of a website, application, or other service
  (collectively, 'API Clients') that is directed towards or is likely to
  be accessed by individuals under the age of 18." "Use of Google AI
  Studio and Gemini API is for developers building with Google AI models
  for professional or business purposes, not for consumer use." "You may
  use only Paid Services when making API Clients available to users in
  the European Economic Area, Switzerland, or the United Kingdom." Unpaid
  tier content is used "to provide, improve, and develop" Google products.
- Generative AI Prohibited Use Policy (last modified 2024-12-17) forbids
  "Impersonating an individual (living or dead) without explicit
  disclosure, in order to deceive."

Our reading: Google is the most explicit of the three that OAuth-backed
subscription access cannot feed a third-party harness, and its under-18
clause is a hard constraint for a public city under RD11's global scope.

### Summary for Hermes and the Guild

| Question | Anthropic | OpenAI | Google |
| --- | --- | --- | --- |
| Consumer plan powering a multi-user service | Not permitted (fact) | Not permitted (reading of ToU) | Not permitted (fact for CLI OAuth) |
| Reselling / passing through inference | API only, "except as expressly approved" (fact) | API: Customer Applications allowed; no key transfer, no account resale (fact) | API Clients allowed; age and region limits (fact) |
| Persona with AI disclosure | Required each session (fact) | Not verified (policy page unreachable) | Disclosure required for impersonation; under-18 exclusion (fact) |

## 6. Cost controls, abuse and latency

Controls, in the order they save money:

1. **Reserve before dispatch, settle after.** Compute a ceiling from the
   formula in §3 (S, N_max, R_max), hold that many credits, run with a
   hard `max_tokens` per step and a step cap, then release the unused
   part. AGENT_CITY already specifies the reservation, idempotency key and
   revocation semantics; this brief only adds the arithmetic. Anthropic's
   `task_budget` (beta) lets the model pace itself to a token ceiling but
   is advisory; the harness must enforce the hard stop.
2. **Per-conversation ceilings.** Cap turns (T) and total context; at
   T=30 a mid-tier chat is 3× a T=8 chat. Summarise or reset history
   past a threshold rather than letting it grow.
3. **Per-user, per-day caps by tier**, expressed in credits, with the
   remaining balance visible in the UI before every action.
4. **Queueing and admission.** Run tasks through a queue with a global
   concurrency limit per model; a burst of 100 tasks at $0.38 each is $38
   in minutes, and rate limits at the provider make it fail messily anyway.
5. **Degraded modes.** When a budget, queue or provider is exhausted,
   fall back to scripted replies, an approved example or a "back in N
   minutes" state, as GUILD_RESIDENTS already requires. The fallback
   should be designed first, because it is also what the public sees under
   RD03.
6. **Kill switches**: per agent, per user, per model and global, flipped
   without a deploy, plus a daily spend alarm at the provider (Anthropic
   and OpenAI both expose spend limits per key or workspace).
7. **Prompt-injection cost blowups.** A tool result (a web page, a repo
   file, a comment in the city) can instruct the agent to loop, fetch a
   500 kB PDF (~125,000 tokens per Anthropic's own example), or call
   itself. Mitigations: `max_content_tokens` on fetches, R caps on every
   tool result, an N cap, no agent-to-agent spending (GUILD_RESIDENTS
   rule), and content treated as content, never as authority
   (AGENT_CITY). Treat repeated cap hits as an abuse signal.
8. **Stolen-card compute abuse.** Credits bought with stolen cards and
   burned on tasks leave SJL with the chargeback and the token bill.
   Standard mitigations: small first purchase, delay before purchased
   credits unlock high-cost actions, velocity limits per account and card,
   3-D Secure, and no cash-out or transfer of credits (the proposed
   no-cash-out rule is also an anti-laundering control; RD07 lists it as
   still to settle).

Latency expectations (assumptions; no measurement):

| Path | Time to first token | Total | What a spatial world tolerates |
| --- | --- | --- | --- |
| Templated status | 0 | 0 | Instant; this is the RD01 slice |
| Hosted small model chat (Haiku/Flash-class), cached prefix | 0.3–1 s | 2–5 s for 200 tokens | Fine with a typing indicator and streaming |
| Hosted frontier chat | 1–3 s | 5–15 s | Needs an animation or an in-world "thinking" state |
| Local 8B on the lab server | 1–3 s | 20–35 s for 200 tokens | Too slow for live dialogue; acceptable for pre-generated lines |
| Agentic task, 25 steps | n/a | 1–10 min | Must be asynchronous: walk away, get a notification, see the result at the agent's desk |

Nielsen's long-standing limits (0.1 s feels instant, 1 s keeps the flow,
10 s loses attention) still describe the experience; a world can hide
1–3 s with movement and animation but not a minute. Stream every chat
reply and never block avatar movement on a model call.

## 7. Voice

Prices fetched 2026-09-18, converted to USD per 1,000 characters where the
vendor bills by character (about 65–70 s of speech at conversational pace).

| Option | Price | Licence / terms notes |
| --- | --- | --- |
| Google Cloud TTS Standard | $4 /M chars ($0.004 /1k); 4M free per month | Commercial use under Google Cloud terms |
| Google Neural2 / WaveNet | $16 / $4 per M chars; 1M / 4M free | Legacy models |
| Google Chirp 3 HD | $30 /M chars ($0.03 /1k); 1M free | Instant custom voice $60 /M |
| Gemini 3.1 Flash TTS (API) | $1 /M text tokens in, $20 /M audio tokens out; 25 audio tokens/s → ~$0.03 /min | Gemini API terms (under-18 exclusion, §5) |
| OpenAI tts-1 / tts-1-hd | $15 / $30 per M chars ($0.015 / $0.03 per 1k) | Services Agreement |
| OpenAI gpt-4o-mini-tts | $0.60 /M text tokens in, $12 /M audio tokens out | |
| ElevenLabs API | Starter $6/mo (10k chars) to Business $990/mo (9.9M chars); overage $0.10 /1k (v3) or $0.05 /1k (conversational) | Commercial licensing on paid plans; check the free tier's non-commercial clause |
| Cartesia Sonic (direct) | Free tier non-commercial; Pro $5/mo (~133 min), Startup $49/mo (~1,667 min), Scale $299/mo | Via Together: $65 /M chars ($0.065 /1k) |
| Kokoro-82M (open, via Together) | $4 /M chars ($0.004 /1k) | Apache 2.0; "trained exclusively on permissive and non-copyrighted audio"; model card welcomes commercial deployment |
| Kokoro-82M self-hosted on CPU | CPU time only | 82M parameters runs on the lab server; not benchmarked here |
| Piper (open, self-hosted) | CPU time only | Engine GPL-3.0. Voice cards say "Piper is intended for personal use and text to speech research only; we do not impose any additional restrictions on voice models. Some voices may have restrictive licenses". Examples: `en_US/ryan` CC BY-NC-SA 4.0; `en_US/hfc_female` CC BY-NC-SA 4.0; `en_US/lessac` Blizzard 2013 licence; `en_GB/alan` "See URL" |
| Coqui XTTS-v2 | self-hosted | Coqui Public Model License; the CPML page returned 404 today; commercial status not verified, treat as non-commercial unless confirmed |
| AI4Bharat Indic-TTS | self-hosted | 13 Indian languages; repository code MIT; model and data licence not stated on the page fetched, must be checked per model |
| Azure Speech | not verified (price table is JavaScript-rendered); free tier 0.5M chars/month stated | Custom voice is limited-access |

Design implications: a Guild agent's stock lines (greetings, office-hours
notices, tutorial steps) should be generated once and cached as clips, so
their cost is a one-off; live TTS applies only to novel text and only for
listeners who turn it on. At 200 tokens (~800 characters) per reply, a
mid-priced hosted voice adds $0.01–$0.025 per reply, comparable to the
whole mid-tier chat turn, so voice should be a tier feature or a credit
item rather than a default. Captions are the accessible default (VD24) and
cost nothing. The browser's `speechSynthesis` remains the zero-cost
read-aloud option. Piper's non-commercial voices rule out several of the
best-known English voices for a public city; pick voices by dataset
licence first.

## 8. Storage and compute unit costs for resident projects

Fetched 2026-09-18. Hetzner and AWS S3 storage tables did not render;
the S3 egress figure comes from a worked example on the pricing page.

| Unit | Provider | Price |
| --- | --- | --- |
| Object storage | Cloudflare R2 Standard | $0.015 /GB-month; egress free; Class A $4.50 /M ops, Class B $0.36 /M ops |
| Object storage | Cloudflare R2 Infrequent | $0.01 /GB-month; $0.01 /GB retrieval |
| Object storage | Backblaze B2 | $6.95 /TB-month (≈$0.007 /GB); egress free up to 3× stored, then $0.01 /GB; free via Cloudflare/Fastly/bunny |
| Object storage | AWS S3 Standard | Storage table not verified; egress $0.09 /GB (EU Ireland example); first 100 GB/month free |
| Object storage | Hetzner | Base price includes 1 TB storage and 1 TB egress; EUR figures not rendered |
| Container / VM | Cloudflare Containers | $0.000020 /vCPU-s, $0.0000025 /GiB-s, $0.00000007 /GB-s disk; egress $0.025 /GB NA/EU; instance types from 1/16 vCPU + 256 MiB to 4 vCPU + 12 GiB |
| Sandbox | E2B | $0.000014 /vCPU-s + $0.0000045 /GiB-s; default 2 vCPU + 4 GiB = $0.166 /h; Hobby $0 with 1-hour sessions, Pro $150/mo with 24-hour sessions |
| Sandbox | Modal | CPU $0.0000131 /core-s (sandbox tier $0.00003942), memory $0.00000222 /GiB-s (sandbox $0.00000667); $30/month free on Starter |
| Sandbox | Anthropic code execution (server tool) | 1,550 free container-hours per org per month, then $0.05 /container-hour; Managed Agents $0.08 /session-hour |
| Sandbox | OpenAI Code Interpreter | $0.03 (1 GB) to $1.92 (64 GB) per 20-minute session |
| Small VM | Hetzner CX23 (2 vCPU, 4 GB, 20 TB traffic) | Price not rendered; page marked plans unavailable |

Derived hosting costs for a resident's personal agent container
(always-on, 730 h): Cloudflare `basic` (1/4 vCPU, 1 GiB) $0.027 /h ≈
$20/month; E2B default $0.166 /h ≈ $121/month; Modal sandbox (1 core,
2 GiB) $0.19 /h ≈ $139/month. Scale-to-zero makes all three near-free
for an agent that wakes on demand, so the credit price for "hosting" should
be per active hour plus per GB stored, not a flat monthly fee. A 1 GB
project on R2 costs $0.015/month; egress is the only storage line that
can surprise, and R2/B2 remove it. Given RD02, the same units apply if
the facility is backed by an SJL product running on the lab server: the marginal
cost is then the lab server's memory and disk, which MULTIPLAYER reserves for the
room server first.

## 9. Measurements still needed and open questions

A cheap real measurement on the Hermes stack, in one afternoon, without
building anything user-facing:

1. Turn on usage logging for one Guild agent for a week. Record per
   request: model, `input_tokens`, `cache_creation_input_tokens`,
   `cache_read_input_tokens`, `output_tokens`, tool calls per task and
   wall time. This replaces S, N, R, A and h in §3 with facts. If the
   harness reports zero cache reads, that alone is the biggest finding.
2. Count the persona: `count_tokens` on each of the 14 system prompts
   plus tool definitions, with both tokenizer generations in mind (the
   ~30% increase on Claude 4.7+).
3. Replay ten real tasks with a step cap of 25 and see how many complete;
   that sets N_max for the reservation formula.
4. Run `llama-bench` on the lab server with a 1B, 3B and 8B Q4_K_M model at a few
   thread counts, and `llama-server -np 2/4` to get achieved tok/s and
   concurrency, while the room server prototype is idle and while it is
   loaded.
5. Synthesise 50 stock lines with Kokoro on the lab server and time it; compare
   audio quality with one hosted voice at $0.004–$0.03 per 1k characters.
6. Count state changes per agent per hour from the AgentPod adapter for a
   day to size the summariser (§3.4) or to show that templated status is
   enough.

Open questions for the owner:

- Under which agreement do the Guild agents run today (API key or a
  subscription), and who at the provider can confirm what "ordinary,
  individual usage" covers for a solo founder's fleet? Section 5 makes
  the RD04 slice an API-key question regardless.
- Which of the three usage assumptions (2 conversations and 0.2 tasks per
  DAU per day, 30% DAU) should be replaced by a target? The monthly cost
  is linear in all three.
- Is the credit pegged to a purchase price ($0.01 was assumed) and what
  gross margin target should price compute and storage (§3.5)? Do earned
  credits (RD07) convert to compute at the same rate as purchased ones?
- Is the summariser wanted at all, or is templated, redacted status
  (free and more honest) the RD01 answer?
- Age scope (RD05 open): the Gemini API cannot be used in a service
  "likely to be accessed by individuals under the age of 18", and
  Anthropic has separate minors guidelines; this constrains both the
  model choice and the public-city entry rules.
- Does voice enter the first slice? If not, the cheapest correct default
  is captions plus cached stock clips, and §7 can wait.
- Which residency tier includes what usage? §3.3 gives $1.30–$12 per
  active user per month by tier as the cost floor to price against.

## Sources

All accessed 2026-09-18 unless marked.

- Anthropic pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Anthropic Consumer Terms: https://www.anthropic.com/legal/consumer-terms
- Anthropic Commercial Terms: https://www.anthropic.com/legal/commercial-terms
- Anthropic Usage Policy: https://www.anthropic.com/legal/aup
- Claude Code legal and compliance: https://code.claude.com/docs/en/legal-and-compliance
- Claude Pro/Max and Claude Code help article: https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan
- OpenAI API pricing: https://developers.openai.com/api/docs/pricing
- OpenAI Terms of Use (Internet Archive capture 2026-09-16): https://web.archive.org/web/20260916192634/https://openai.com/policies/terms-of-use/
- OpenAI Services Agreement (Internet Archive capture 2026-09-15): https://web.archive.org/web/20260915134200/https://openai.com/policies/services-agreement/
- OpenAI Usage Policies (not fetched; 403): https://openai.com/policies/usage-policies/
- OpenAI Codex authentication: https://learn.chatgpt.com/docs/auth
- Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Gemini API Additional Terms: https://ai.google.dev/gemini-api/terms
- Google Generative AI Prohibited Use Policy: https://policies.google.com/terms/generative-ai/use-policy
- Gemini CLI terms and privacy: https://geminicli.com/docs/resources/tos-privacy/
- Groq models and prices: https://console.groq.com/docs/models
- Together pricing: https://www.together.ai/pricing
- Fireworks serverless pricing: https://docs.fireworks.ai/serverless/pricing and https://fireworks.ai/pricing
- DeepSeek pricing: https://api-docs.deepseek.com/quick_start/pricing
- OpenRouter FAQ (fees): https://openrouter.ai/docs/faq
- Cerebras pricing (tables did not render): https://www.cerebras.ai/pricing
- llamafile CPU benchmarks: https://github.com/mozilla-ai/llamafile/discussions/450
- Ryzen 9 7950X llama.cpp benchmark: https://markaicode.com/benchmarks/llamacpp-tokens-per-second-benchmark/
- geerlingguy/ai-benchmarks: https://github.com/geerlingguy/ai-benchmarks
- llama.cpp server README: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- RunPod pricing: https://www.runpod.io/pricing
- Lambda pricing: https://lambda.ai/pricing
- Modal pricing: https://modal.com/pricing
- Nielsen response-time limits (not re-fetched today): https://www.nngroup.com/articles/response-times-3-important-limits/
- ElevenLabs API pricing: https://elevenlabs.io/pricing/api
- Cartesia pricing: https://cartesia.ai/pricing
- Google Cloud Text-to-Speech pricing: https://cloud.google.com/text-to-speech/pricing
- Azure Speech pricing (tables did not render): https://azure.microsoft.com/en-us/pricing/details/cognitive-services/speech-services/
- Azure text to speech overview: https://learn.microsoft.com/en-us/azure/ai-services/speech-service/text-to-speech
- Piper engine: https://github.com/OHF-Voice/piper1-gpl ; voices: https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md ; model cards under https://huggingface.co/rhasspy/piper-voices
- Kokoro-82M: https://huggingface.co/hexgrad/Kokoro-82M
- Coqui TTS: https://github.com/coqui-ai/TTS ; XTTS-v2: https://huggingface.co/coqui/XTTS-v2 (CPML page 404)
- AI4Bharat Indic-TTS: https://github.com/AI4Bharat/Indic-TTS
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/
- Cloudflare Containers pricing: https://developers.cloudflare.com/containers/pricing/
- Backblaze B2 pricing: https://www.backblaze.com/cloud-storage/pricing
- AWS S3 pricing: https://aws.amazon.com/s3/pricing/
- Hetzner Object Storage (prices did not render): https://www.hetzner.com/storage/object-storage/ ; docs: https://docs.hetzner.com/storage/object-storage/overview/
- Hetzner Cloud (prices did not render): https://www.hetzner.com/cloud/cost-optimized/
- E2B pricing: https://e2b.dev/pricing
- Repo context: [VISION_DECISIONS](../planning/VISION_DECISIONS.md), [AGENT_CITY](../gameplay/AGENT_CITY.md), [FOUNDING_AGENTS](../vision/FOUNDING_AGENTS.md), [GUILD_RESIDENTS](../vision/GUILD_RESIDENTS.md), [MULTIPLAYER](../architecture/MULTIPLAYER.md)
