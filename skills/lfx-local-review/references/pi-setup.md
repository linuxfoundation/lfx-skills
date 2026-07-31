<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Setting up Pi for local review

Pi is what makes this review **cross-model**. The reviewers read the same
skills either way; running them on a different model is the whole point,
because a model reviewing its own work shares its own blind spots.

Without Pi the trio still runs — on Claude subagents — but that is a same-model
review and the host says so every time.

## Install and authenticate

```bash
npm install -g @awebai/pi     # or see https://aweb.ai/docs/pi/
pi                            # then /login, and pick your GitHub Copilot seat
```

Pi's Copilot credentials come from its own `/login`. Nothing here reads,
copies or passes them.

## Check what this repo will do

```bash
<skill dir>/scripts/run-pi.sh --readiness --repo <path>
```

`<skill dir>` is the directory holding the `lfx-local-review` `SKILL.md` — the
one this file sits under. Resolve it to an absolute path and use that. The
commands below are written the same way. A path like
`skills/lfx-local-review/...` only works from an `lfx-skills` checkout, and you
are normally standing in a service repo where it does not exist.

It prints one of:

| Result | Meaning |
|---|---|
| `PI_READY` | the trio will run on Pi |
| `PI_NOT_INSTALLED` | `pi` is not on `PATH` |
| `PI_UNAUTHENTICATED` | `pi` cannot list models for the provider |
| `PI_MODEL_UNAVAILABLE` | the provider does not serve the configured model |

The last three are **not failures**. They are the decision to run the whole
trio on Claude instead, and the host prints the setup message with them.

This check is best-effort by nature: a successful model listing proves the
model is discoverable *now*, not that authentication will still hold in ten
minutes. If it lapses mid-run the Pi run fails plainly and the whole trio is
rerun — the host never switches harness half way through.

## Model and provider

Defaults are `github-copilot` and `gpt-5.6-sol`. Override per run:

```bash
LFX_LOCAL_REVIEW_MODEL=gpt-5.5 <skill dir>/scripts/run-pi.sh --repo <path>
LFX_LOCAL_REVIEW_PROVIDER=<provider> ...
```

`pi --list-models <provider>` shows what your seat actually serves.

## How reviewers are invoked

```text
pi -p --mode text --model <provider>/<model> --no-session --no-approve \
   --no-skills --no-context-files --no-prompt-templates --no-extensions \
   --tools read,bash,grep,find,ls \
   --skill <one absolute SKILL.md> "<role prompt>"
```

The discovery flags matter: a reviewer sees exactly the one skill it was given,
with no ambient `AGENTS.md`, `CLAUDE.md`, project skill, prompt template or
extension leaking in. `--no-approve` is the least-trust flag that still loads
an explicitly passed skill, including one that lives inside the repo under
review.

`--no-extensions` also keeps stdout clean. An installed extension can otherwise
print diagnostics, and the transport here is plain text — the reviewer's
Markdown is taken verbatim from stdout, with stderr kept separate and never
merged into a successful report.

**This is not a sandbox.** Reviewers run with ordinary local-user capability —
shell, git, builds and tests when useful, read-only GitHub inspection. Pi and
Claude reviewers have the same trust posture; nothing here restricts what they
*can* do, and no claim to the contrary should be made about either. What keeps
a review honest is the instructions in the skill: report, and never
intentionally modify tracked source, tracked config, Git history, or remote
review state. Disposable build, test and cache artifacts are expected and fine.
