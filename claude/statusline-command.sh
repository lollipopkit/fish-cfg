#!/bin/sh
# Claude Code status line — hydro-style prompt rebuilt in pure sh.
# We do NOT call "fish -c 'fish_prompt'" because:
#  1. config.fish sources conda + orbstack init scripts (very slow / may hang)
#  2. hydro's internal variables ($__hydro_*) are absent in a one-shot fish -c
#  3. non-interactive fish may not lazy-load the fish_prompt function at all
# Instead we reconstruct the same visual elements using fast shell commands.

input=$(cat)

# --- hydro-style prompt parts ---
# pwd: use cwd from JSON input (avoids running pwd in a potentially wrong dir)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
# Abbreviate home directory to ~
home="$HOME"
case "$cwd" in
  "$home"*) cwd="~${cwd#$home}" ;;
esac

# git branch + dirty flag (hydro shows "branch!" when dirty)
git_part=""
# Use the cwd field from JSON for git; fall back to actual cwd
actual_cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')
if [ -z "$actual_cwd" ]; then actual_cwd=$(pwd); fi
git_branch=$(git -C "$actual_cwd" symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$git_branch" ]; then
  git_dirty=$(git -C "$actual_cwd" status --porcelain 2>/dev/null)
  if [ -n "$git_dirty" ]; then
    git_part="${git_branch}!"
  else
    git_part="$git_branch"
  fi
fi

# --- model ---
# display_name is the short label ("Opus 5 (1M)"); id is the full model id and
# only stands in when a build sends no display name.
model_name=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // empty')

# --- context window + rate limit quota ---
# `numbers` drops null and anything non-numeric, so the awk expressions below
# never interpolate a string. These fields are null until the first API response.
ctx_used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage | numbers')
five_used=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage | numbers')
five_resets=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at | numbers')
week_used=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage | numbers')
week_resets=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at | numbers')

# Colors — match hydro's default palette as closely as possible.
# hydro uses: pwd=blue(#5b9bd5-ish), branch=green(#78c2a4), dirty=yellow
# In 256-color: blue≈74, green≈72/79, yellow≈221, gray≈109, amber≈215, red≈203
blue='\033[38;5;74m'
green='\033[38;5;79m'
yellow='\033[38;5;221m'
gray='\033[38;5;109m'
amber='\033[38;5;215m'
red='\033[38;5;203m'
purple='\033[38;5;140m'
dim='\033[2m'
reset='\033[0m'

quota_parts=""

# --- context window usage ---
# Percentage of the window already occupied. The value is relative to the
# session's own window, so a 1M-context model reads on the same scale as a 200k
# one. Shown as "used".
ctx_part=""
if [ -n "$ctx_used" ]; then
  ctx_color="$gray"
  [ "$(awk "BEGIN { print ($ctx_used >= 70) ? 1 : 0 }")" = "1" ] && ctx_color="$amber"
  [ "$(awk "BEGIN { print ($ctx_used >= 90) ? 1 : 0 }")" = "1" ] && ctx_color="$red"
  ctx_part="${ctx_color}$(awk "BEGIN { printf \"%.0f\", $ctx_used }")%${reset}"
fi

# The model shares the context bracket: the percentage is relative to *this*
# model's window, so the two belong together.
model_part=""
[ -n "$model_name" ] && model_part="${purple}${model_name}${reset}"

# Format unix epoch into a human-readable countdown: "4h", "45m", "30s", or "now"
_fmt_remaining() {
  resets_at="$1"
  [ -z "$resets_at" ] && return
  now=$(date +%s)
  diff=$((resets_at - now))
  [ "$diff" -le 0 ] && printf "now" && return
  h=$((diff / 3600))
  m=$(((diff % 3600) / 60))
  s=$((diff % 60))
  d=$((diff / 86400))
  if [ "$d" -gt 0 ]; then
    printf "%dd" "$d"
  elif [ "$h" -gt 0 ]; then
    printf "%dh" "$h"
  else
    printf "%dm" "$m"
  fi
}

_append_quota() {
  used="$1"; resets_at="$2"
  [ -z "$used" ] && return
  countdown=$(_fmt_remaining "$resets_at")
  rem=$(awk "BEGIN { printf \"%.0f\", 100 - $used }")
  color="$gray"
  [ "$(awk "BEGIN { print ($used > 70) ? 1 : 0 }")" = "1" ] && color="$amber"
  if [ -n "$countdown" ]; then
    part="${color}${rem}%${reset}${dim} ${countdown}${reset}"
  else
    part="${color}${rem}%${reset}"
  fi
  if [ -z "$quota_parts" ]; then
    quota_parts="$part"
  else
    quota_parts="${quota_parts}${dim} · ${reset}${part}"
  fi
}

_append_quota "$five_used" "$five_resets"
_append_quota "$week_used" "$week_resets"

# --- assemble final line ---
# hydro layout: <pwd>  <branch[!]>  [<model> · <ctx used%>]  [quota]
# pwd in blue, branch in green (dirty marker in yellow)
prompt_pwd="${blue}${cwd}${reset}"

prompt_git=""
if [ -n "$git_part" ]; then
  # Split branch and dirty marker for separate coloring
  branch_name="${git_part%!}"
  if [ "$git_part" != "$branch_name" ]; then
    # dirty
    prompt_git="  ${green}${branch_name}${yellow}!${reset}"
  else
    prompt_git="  ${green}${branch_name}${reset}"
  fi
fi

line="${prompt_pwd}${prompt_git}"

model_ctx="$model_part"
if [ -n "$ctx_part" ]; then
  if [ -n "$model_ctx" ]; then
    model_ctx="${model_ctx}${dim} · ${reset}${ctx_part}"
  else
    model_ctx="$ctx_part"
  fi
fi

[ -n "$model_ctx" ] && line="${line}  ${dim}[${reset}${model_ctx}${dim}]${reset}"
[ -n "$quota_parts" ] && line="${line}  ${dim}[${reset}${quota_parts}${dim}]${reset}"
printf "%b" "$line"
