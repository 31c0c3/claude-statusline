# claude-statusline

A one-line [Claude Code](https://code.claude.com) status line in bash and jq.
Plain text when all is well; yellow or red only when something needs attention.

```
claude-plugins ⌥ main* | statusline setup | ██████░░ 146k/200k | C 97% ● 47m | 8% ↻ 4h16m | $2.88   d1411d72  Opus 5.5 high
```

## Segments

| Segment | Shows | Warns |
|---|---|---|
| `claude-plugins ⌥ main*` | Folder, git branch, `*` for uncommitted changes | `*` in yellow |
| `statusline setup` | Session name from `/rename`, or the generated title, cut to 28 characters | |
| `██████░░ 146k/200k` | Context used, measured against a 200k soft cap; past it, against the full window | Yellow past the cap, with `▲` |
| `C 97% ● 47m` | Prompt-cache hit rate, time until the cache expires | Hit rate below 80% (red below 50%); `○ ↑ 117k` once expired: what the next message re-caches |
| `8% ↻ 4h16m` | 5-hour limit used and time to reset (Pro/Max) | Yellow from 50%, red from 80% |
| `7d 40% ▲` | 7-day limit, shown only when ahead of an even 1/7-per-day pace | Yellow; red when more than a day ahead |
| `$2.88` | Session cost | |
| `d1411d72-… Opus 5.5 high` | Session ID in gray, then model and effort, right-aligned. The full ID when it fits (usable with `claude -r`), else its first 8 characters, else none | |

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
| `STATUSLINE_RIGHT_MARGIN` | `4` | Columns kept free right of the model; raise it if the line wraps |

## Two lines

Claude Code shows each line the script prints as its own row. If the full session ID does not fit,
it can move to a second line, right-aligned under the model, at the cost of one row of height.
Not built in: edit the last lines of the jq program in `statusline.sh`.
