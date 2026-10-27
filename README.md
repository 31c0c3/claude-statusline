# claude-statusline

A two-line [Claude Code](https://code.claude.com) status line in bash and jq.
Plain text when all is well; yellow or red only when something needs attention.

```
claude-plugins ⌥ main* | ██████░░ 146k/200k | C 97% ● 47m | $2.88                                            Opus 5.5 high
                                                        8% ↻ 4h16m | 40/57% ↻ 3d12h | d1411d72-0c5e-4f3a-9b7d-2e8a6c41f905
```

## Segments

| Segment | Shows | Warns |
|---|---|---|
| `claude-plugins ⌥ main*` | Folder, git branch, `*` for uncommitted changes | `*` in yellow |
| `██████░░ 146k/200k` | Context used, measured against a 200k soft cap; past it, against the full window | Yellow past the cap, with `▲` |
| `C 97% ● 47m` | Prompt-cache hit rate, time until the cache expires | Hit rate below 80% (red below 50%); `○ ↑ 117k` once expired: what the next message re-caches |
| `$2.88` | Session cost | |
| `Opus 5.5 high` | Model and effort, right-aligned | |
| `8% ↻ 4h16m` | 5-hour limit used and time to reset (Pro/Max), gray on the second line | Usage yellow from 50%, red from 80% |
| `40/57% ↻ 3d12h` | 7-day limit used out of the budget so far, which grows by 1/7 at the start of each day | Usage yellow past the budget, red more than a day past |
| `d1411d72-0c5e-…` | Session ID for `claude -r`, gray, right-aligned under the model | |

## Install

```bash
git clone https://github.com/31c0c3/claude-statusline.git
```

In `~/.claude/settings.json`, with the path to your clone:

```json
"statusLine": {
  "type": "command",
  "command": "bash /path/to/claude-statusline/statusline.sh",
  "refreshInterval": 30
}
```

`refreshInterval` keeps the countdowns ticking while the session is idle.

Needs `jq` and `git`. The cache segment needs Claude Code 2.1.251 or later.

## Options

Set in the `env` block of `settings.json`:

| Variable | Default | Effect |
|---|---|---|
| `STATUSLINE_SOFT_CTX` | `200000` | Soft context cap for the bar. Long context degrades well before a 1M window fills |
| `STATUSLINE_RIGHT_MARGIN` | `4` | Columns kept free right of the model and session ID; raise it if the line wraps |
