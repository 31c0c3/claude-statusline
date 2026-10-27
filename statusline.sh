#!/bin/bash
# Claude Code status line: folder ⌥ branch* | ctx bar | cache | $cost ... model effort
#                                                          ... 5h | 7d | session ID
# Icons: Arrows or Geometric Shapes glyphs, each followed by a space. Rarer glyphs come from a
# fallback font, render wider than their one cell, and overlap the next character.
input=$(cat)
dir=$(jq -r '.workspace.current_dir' <<<"$input")
branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
dirty=$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1)
# In Herdr the session name labels Claude's pane instead, on the border beside a split; it appears after the first message
name=$(jq -r '.session_name // empty' <<<"$input")
[[ -n $HERDR_PANE_ID && -n $name ]] && herdr pane rename "$HERDR_PANE_ID" "$name" >/dev/null 2>&1

# Soft context cap: the bar measures against this until usage passes it, then switches to the full window with a warning
soft_cap=${STATUSLINE_SOFT_CTX:-200000}
# Terminal width from Claude Code; the margin keeps right-aligned text clear of the UI's own row padding
cols=${COLUMNS:-0}
margin=${STATUSLINE_RIGHT_MARGIN:-4}

# Single-quoted: a ' anywhere, comments included, ends it. Read input fields at the top, where . is still the input.
jq -rj --arg branch "$branch" --arg dirty "$dirty" --argjson soft "$soft_cap" --argjson cols "$cols" --argjson margin "$margin" '
  # Color is for warnings: yellow (33) or red (31). Gray (90) marks secondary text; "" leaves the terminal default
  def paint(code; s): if code == "" then s else "\u001b[\(code)m\(s)\u001b[0m" end;
  def pad2: tostring | if length < 2 then "0" + . else . end;
  # Whole thousands; millions keep one decimal unless whole: 41k, 1M, 1.2M
  def human(n):
    if n >= 999500 then "\(n / 1e5 | round / 10)M"
    elif n >= 1e3 then "\(n / 1e3 | round)k"
    else "\(n | round)" end;
  def money(x): (x * 100 | round) as $c | "$\($c / 100 | floor).\($c % 100 | pad2)";
  # Time until an epoch timestamp: 3d04h / 2h05m / 47m / <1m
  def until(ts): ([ts - now, 0] | max) as $s
    | if $s >= 86400 then "\($s / 86400 | floor)d\($s % 86400 / 3600 | floor | pad2)h"
      elif $s >= 3600 then "\($s / 3600 | floor)h\($s % 3600 / 60 | floor | pad2)m"
      elif $s >= 60 then "\($s / 60 | floor)m"
      else "<1m" end;
  def warn(yellow; red; s): paint(if red then "31" elif yellow then "33" else "" end; s);
  # Subscription limit: all gray while fine; on a warning only the usage takes the color
  def limit(yellow; red; used; note; ts):
    if red or yellow then warn(yellow; red; used) + paint("90"; note) + " ↻ " + until(ts)
    else paint("90"; used + note + " ↻ " + until(ts)) end;

  paint("90"; " | ") as $sep
  | (.model.display_name + (if .effort.level then paint("90"; " " + .effort.level) else "" end)) as $model
  | .session_id as $sid
  | .context_window.context_window_size as $size
  | (.context_window.current_usage // {} | [.input_tokens, .cache_creation_input_tokens, .cache_read_input_tokens] | add // 0) as $used
  | ($used > $soft and $size > $soft) as $over
  | (if $over then $size else [$size, $soft] | min end) as $cap
  | ($used * 100 / $cap) as $pct
  | ([($pct * 8 / 100 | round), 8] | min) as $filled

  | ([
      (.workspace.current_dir | split("/") | last)
        + (if $branch != "" then " ⌥ " + $branch + (if $dirty != "" then paint("33"; "*") else "" end) else "" end),
      warn($over; false; "█" * $filled // "") + paint("90"; "░" * (8 - $filled) // "")
        + " \(human($used))/\(human($cap))"
        + (if $over then paint("33"; " ▲") else "" end),
      # Cache: hit ratio, then time left while warm, or what the next turn re-caches once cold
      (.prompt_cache // empty | select(.caching_observed)
       | "C " + warn(.hit_ratio < 0.8; .hit_ratio < 0.5; "\(.hit_ratio * 100 | floor)%")
         + (if .warm and (.expires_at // 0) > now then " ● " + until(.expires_at)
            else paint("33"; " ○" + (if .recache_tokens_if_cold then " ↑ " + human(.recache_tokens_if_cold) else "" end)) end)),
      money(.cost.total_cost_usd)
    ] | join($sep)) as $left
  # Subscription limits (Pro/Max only), on the second line
  | ([
      (.rate_limits.five_hour // empty
       | limit(.used_percentage >= 50; .used_percentage >= 80; "\(.used_percentage | round)%"; ""; .resets_at)),
      # 7-day used/budget: the budget grows by 1/7 at the start of each day; red when a day ahead
      (.rate_limits.seven_day // empty
       | ([((7 * 86400 - (.resets_at - now)) / 86400 | ceil), 1] | max) as $day
       | ([$day * 100 / 7, 100] | min) as $budget
       | limit(.used_percentage > $budget; .used_percentage > $budget + 100 / 7;
           "\(.used_percentage | round)"; "/\($budget | round)%"; .resets_at))
    ] | join($sep)) as $limits
  # Right-align r after l to the terminal width; appended as one more segment when it does not fit
  | def width: gsub("\u001b\\[[0-9;]*m"; "") | length;
    def align(l; r): ($cols - $margin - (l | width) - (r | width)) as $gap
      | if $cols > 0 and $gap >= 2 then l + " " * $gap + r
        elif l == "" then r
        else l + $sep + r end;
    align($left; $model)
  # Second line: limits and session ID, right-aligned under the model. Claude Code trims
  # leading spaces, so the line starts with a reset code
  + ([$limits, ($sid // "" | paint("90"; .))] | map(select(. != "")) | join($sep)) as $right
  | (if $right != "" then "\n\u001b[0m" + align(""; $right) else "" end)
' <<<"$input"
