#!/bin/bash
# Claude Code status line: folder ⌥ branch* | session | ctx bar | cache | 5h | 7d | $cost ... model effort
# Icons: Arrows or Geometric Shapes glyphs, each followed by a space. Rarer glyphs come from a
# fallback font, render wider than their one cell, and overlap the next character.
input=$(cat)
dir=$(jq -r '.workspace.current_dir' <<<"$input")
branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
dirty=$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1)

# Soft context cap: the bar measures against this until usage passes it, then switches to the full window with a warning
soft_cap=${STATUSLINE_SOFT_CTX:-200000}
# Terminal width from Claude Code; the margin keeps right-aligned text clear of the UI's own row padding
cols=${COLUMNS:-0}
margin=${STATUSLINE_RIGHT_MARGIN:-4}

jq -rj --arg branch "$branch" --arg dirty "$dirty" --argjson soft "$soft_cap" --argjson cols "$cols" --argjson margin "$margin" '
  # Color is for warnings: yellow (33) or red (31). Gray (90) marks secondary text; "" leaves the terminal default
  def paint(code; s): if code == "" then s else "\u001b[\(code)m\(s)\u001b[0m" end;
  def pad2: tostring | if length < 2 then "0" + . else . end;
  def dec1(x): (x * 10 | round / 10 | tostring) | if test("\\.") then . else . + ".0" end;
  def human(n):
    if n >= 1e6 then dec1(n / 1e6) + "M"
    elif n >= 1e5 then "\(n / 1e3 | round)k"
    elif n >= 1e3 then dec1(n / 1e3) + "k"
    else "\(n | round)" end;
  def money(x): (x * 100 | round) as $c | "$\($c / 100 | floor).\($c % 100 | pad2)";
  # Time until an epoch timestamp: 2h05m / 47m / <1m
  def until(ts): ([ts - now, 0] | max) as $s
    | if $s >= 3600 then "\($s / 3600 | floor)h\($s % 3600 / 60 | floor | pad2)m"
      elif $s >= 60 then "\($s / 60 | floor)m"
      else "<1m" end;
  def warn(yellow; red; s): paint(if red then "31" elif yellow then "33" else "" end; s);

  paint("90"; " | ") as $sep
  | (.model.display_name + (if .effort.level then paint("90"; " " + .effort.level) else "" end)) as $model
  | .context_window.context_window_size as $size
  | (.context_window.current_usage // {} | [.input_tokens, .cache_creation_input_tokens, .cache_read_input_tokens] | add // 0) as $used
  | ($used > $soft and $size > $soft) as $over
  | (if $over then $size else [$size, $soft] | min end) as $cap
  | ($used * 100 / $cap) as $pct
  | ([($pct / 10 | round), 10] | min) as $filled

  | [
      (.workspace.current_dir | split("/") | last)
        + (if $branch != "" then " ⌥ " + $branch + (if $dirty != "" then paint("33"; "*") else "" end) else "" end),
      # Session name from /rename or the AI-generated title, truncated
      (.session_name // empty | if length > 32 then .[:31] + "…" else . end),
      warn($over; false; "█" * $filled // "") + paint("90"; "░" * (10 - $filled) // "")
        + " \(human($used))/\(human($cap))  \($pct | round)%"
        + (if $over then paint("33"; " ▲ >" + human($soft)) else "" end),
      # Cache: hit ratio, then time left while warm, or what the next turn re-caches once cold
      (.prompt_cache // empty | select(.caching_observed)
       | "cache " + warn(.hit_ratio < 0.8; .hit_ratio < 0.5; "\(.hit_ratio * 100 | floor)%")
         + (if .warm and (.expires_at // 0) > now then " ● " + until(.expires_at)
            else paint("33"; " ○" + (if .recache_tokens_if_cold then " ↑ " + human(.recache_tokens_if_cold) else "" end)) end)
         + (if (.misses // 0) > 0 then " × \(.misses)" else "" end)),
      # 5-hour subscription limit (Pro/Max only)
      (.rate_limits.five_hour // empty
       | "5h " + warn(.used_percentage >= 50; .used_percentage >= 80; "\(.used_percentage | round)%") + " ↻ " + until(.resets_at)),
      # 7-day limit, shown only when ahead of pace: the budget grows by 1/7 at the start of each day of the window
      (.rate_limits.seven_day // empty
       | ([((7 * 86400 - (.resets_at - now)) / 86400 | ceil), 1] | max) as $day
       | ([$day * 100 / 7, 100] | min) as $budget
       | select(.used_percentage > $budget)
       | "7d " + warn(true; .used_percentage > $budget + 100 / 7; "\(.used_percentage | round)% ▲")),
      money(.cost.total_cost_usd)
    ]
  | join($sep) as $left
  # Model right-aligned to the terminal width; appended as one more segment when it does not fit
  | def width: gsub("\u001b\\[[0-9;]*m"; "") | length;
    ($cols - $margin - ($left | width) - ($model | width)) as $pad
  | if $cols > 0 and $pad >= 2 then $left + " " * $pad + $model else $left + $sep + $model end
' <<<"$input"
