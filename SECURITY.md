# Security policy

## Reporting a vulnerability

Please report security problems **privately**, not in a public issue, pull
request or discussion.

Use GitHub's private vulnerability reporting: open
[a new security advisory](https://github.com/SuperJackfruitLabs/agentnagar/security/advisories/new)
(the repository's **Security** tab, then **Report a vulnerability**). Only
you and the maintainers can see it.

Include what you can:

- the affected component (the city core, the command line or MCP server, the
  Godot client, a package for a given platform, the build scripts or a
  prototype) and the version or commit;
- what an attacker could do, and the steps or a proof of concept to
  reproduce it;
- any fix or mitigation you suggest.

We aim to acknowledge a report within seven days, agree a fix and a
disclosure date with you, and credit you in the advisory unless you prefer
not to be named.

## Supported versions

Agentnagar is pre-release. Only the default branch and the latest tagged
release receive fixes.

## Scope

In scope: the code in this repository and the packages its release workflow
publishes. Out of scope: the third-party components listed in
[THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt) (report those upstream,
for example to the [Godot Engine](https://github.com/godotengine/godot/security)),
and social engineering or physical attacks.

The prototypes and packages use fictional fixture data only; please do not
test against other people's systems or accounts.
