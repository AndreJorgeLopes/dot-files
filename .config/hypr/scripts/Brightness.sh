#!/usr/bin/env bash
# Hyprland brightness controller
# Internal (eDP-*) via brillo; externals via ddcutil (VCP 0x10)
# Supports: --get | --inc | --dec | + | - | max | min [--all|-all]

# ---- Settings ----
iDIR="$HOME/.config/swaync/icons"
notification_timeout=1000

step_internal=8  # % step for laptop panel
step_external=15 # % step for externals
min_pct=0
max_pct=100

brillo_transition_us=150000
ddc_sleep_mult=".2"

# ---- Hyprland helpers ----
FOCUSED_NAME=""

list_monitors() {
  # prints: name<TAB>focused(true/false)
  hyprctl monitors -j 2>/dev/null | jq -r '.[] | [.name, (.focused|tostring)] | @tsv'
}

get_focused_name() {
  FOCUSED_NAME=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name')
  [[ -n "$FOCUSED_NAME" ]]
}

# case-insensitive internal panel
is_internal_name() {
  local n="${1,,}"
  [[ "$n" =~ ^edp(-|$) ]]
}

# ddcutil --display wants the trailing number from the connector name (dp-3 -> 3)
name_to_ddc_display() {
  local n="$1"
  if [[ "$n" =~ ([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# ---- Icons + notifications ----
get_icon_path() {
  local brightness=$1
  local level=$(((brightness + 19) / 20 * 20))
  ((level > 100)) && level=100
  echo "$iDIR/brightness-${level}.png"
}

send_notification() {
  local brightness=$1 icon_path=$2
  notify-send -e \
    -h string:x-canonical-private-synchronous:brightness_notif \
    -h int:value:"$brightness" \
    -u low -i "$icon_path" \
    "Screen" "Brightness: ${brightness}%"
}

# ---- ddcutil parsing (curr/max) ----
ddc_read_curr_max_by_disp() {
  local disp="$1" out curr max
  out=$(ddcutil --sleep-multiplier="$ddc_sleep_mult" --display="$disp" getvcp 10 2>/dev/null)
  curr=$(echo "$out" | awk -F'[=, ]+' '/Brightness|VCP/ {for(i=1;i<=NF;i++){if($i=="value"){print $(i+1); exit}}}')
  max=$(echo "$out" | awk -F'[=, ]+' '/Brightness|VCP/ {for(i=1;i<=NF;i++){if($i=="max"){print $(i+2); exit}}}')
  if [[ -z "$curr" || -z "$max" ]]; then
    out=$(ddcutil -t --display="$disp" getvcp 10 2>/dev/null)
    read -r curr max <<<"$(echo "$out" | awk '{for(i=1;i<=NF;i++){ if($i ~ /^[0-9]+$/) a[++n]=$i } END{ if(n>=2) print a[n-1], a[n]; }}')"
  fi
  [[ -z "$curr" ]] && curr=0
  [[ -z "$max" || "$max" -eq 0 ]] && max=100
  echo "$curr $max"
}

# ---- Read brightness (%) ----
get_brightness_for() {
  local name="$1"
  if is_internal_name "$name"; then
    local val
    val=$(brillo -G 2>/dev/null || echo 0)
    printf '%d\n' "$(printf '%.0f' "$val")"
  else
    local disp curr max
    disp=$(name_to_ddc_display "$name")
    [[ -z "$disp" ]] && {
      echo "0"
      return
    }
    read -r curr max <<<"$(ddc_read_curr_max_by_disp "$disp")"
    printf '%d\n' $(((curr * 100 + max / 2) / max))
  fi
}

get_brightness() {
  get_focused_name || {
    echo "0"
    return
  }
  get_brightness_for "$FOCUSED_NAME"
}

# ---- Absolute set (%) ----
set_abs_for() {
  local name="$1" pct="$2"
  ((pct < min_pct)) && pct=$min_pct
  ((pct > max_pct)) && pct=$max_pct

  if is_internal_name "$name"; then
    brillo -u "$brillo_transition_us" -S "$pct"
  else
    local disp curr max raw
    disp=$(name_to_ddc_display "$name") || return
    [[ -z "$disp" ]] && return
    # Always compute against monitor max (handles 0..100, 0..255, etc.)
    read -r curr max <<<"$(ddc_read_curr_max_by_disp "$disp")"
    raw=$(((pct * max + 50) / 100))
    ddcutil --sleep-multiplier="$ddc_sleep_mult" --display="$disp" setvcp 10 "$raw" >/dev/null 2>&1
  fi
}

# ---- Relative change by delta (%) ----
change_for() {
  local name="$1" delta="$2"
  if is_internal_name "$name"; then
    if ((delta >= 0)); then
      brillo -u "$brillo_transition_us" -A "$delta"
    else
      brillo -u "$brillo_transition_us" -U "$((-delta))"
    fi
    local val
    val=$(brillo -G 2>/dev/null || echo 0)
    printf '%d\n' "$(printf '%.0f' "$val")"
  else
    local disp dir amt
    disp=$(name_to_ddc_display "$name")
    [[ -z "$disp" ]] && {
      echo "0"
      return
    }
    if ((delta >= 0)); then
      dir="+"
      amt="$delta"
    else
      dir="-"
      amt="$((-delta))"
    fi
    ddcutil --sleep-multiplier="$ddc_sleep_mult" --display="$disp" setvcp 10 "$dir" "$amt" >/dev/null 2>&1
    get_brightness_for "$name"
  fi
}

# ---- Apply to all (now notifies per monitor) ----
apply_all_delta() {
  local plusminus="$1" # "+" or "-"
  while IFS=$'\t' read -r name _focused; do
    local new
    if [[ "$plusminus" == "+" ]]; then
      new=$(change_for "$name" "$([[ $(
        is_internal_name "$name"
        echo $?
      ) -eq 0 ]] && echo "$step_internal" || echo "$step_external")")
    else
      new=$(change_for "$name" "$([[ $(
        is_internal_name "$name"
        echo $?
      ) -eq 0 ]] && echo "-$step_internal" || echo "-$step_external")")
    fi
    send_notification "$new" "$(get_icon_path "$new")"
  done < <(list_monitors)
}

apply_all_abs() {
  local pct="$1"
  while IFS=$'\t' read -r name _focused; do
    set_abs_for "$name" "$pct"
    # read back to show accurate %
    local v
    v=$(get_brightness_for "$name")
    send_notification "$v" "$(get_icon_path "$v")"
  done < <(list_monitors)
}

# ---- Focused helpers ----
set_brightness_abs() {
  get_focused_name || {
    echo "Could not detect focused monitor." >&2
    exit 1
  }
  set_abs_for "$FOCUSED_NAME" "$1"
  send_notification "$1" "$(get_icon_path "$1")"
}

change_brightness() {
  get_focused_name || {
    echo "Could not detect focused monitor." >&2
    exit 1
  }
  local new
  new=$(change_for "$FOCUSED_NAME" "$1")
  send_notification "$new" "$(get_icon_path "$new")"
}

# ---- CLI ----
show_usage() {
  cat <<EOF
Usage: $(basename "$0") [--get | --inc | --dec | + | - | max | min] [--all|-all]
Default: --get (focused)
Examples:
  $(basename "$0") +
  $(basename "$0") --dec --all
  $(basename "$0") max -all
EOF
}

op="" all_flag=false
[[ $# -eq 0 ]] && op="--get"
for a in "$@"; do
  case "$a" in
  --get) op="--get" ;;
  --inc | +) op="--inc" ;;
  --dec | -) op="--dec" ;;
  max | --max) op="max" ;;
  min | --min) op="min" ;;
  --all | -all) all_flag=true ;;
  -h | --help | help)
    show_usage
    exit 0
    ;;
  *) ;;
  esac
done

case "$op" in
"--get")
  if $all_flag; then
    while IFS=$'\t' read -r name _; do
      printf "%s\t%s%%\n" "$name" "$(get_brightness_for "$name")"
    done < <(list_monitors)
  else
    get_brightness
  fi
  ;;
"--inc")
  if $all_flag; then
    apply_all_delta "+"
  else
    if get_focused_name && is_internal_name "$FOCUSED_NAME"; then
      change_brightness "$step_internal"
    else
      change_brightness "$step_external"
    fi
  fi
  ;;
"--dec")
  if $all_flag; then
    apply_all_delta "-"
  else
    if get_focused_name && is_internal_name "$FOCUSED_NAME"; then
      change_brightness "-$step_internal"
    else
      change_brightness "-$step_external"
    fi
  fi
  ;;
"max")
  if $all_flag; then apply_all_abs 100; else set_brightness_abs 100; fi
  ;;
"min")
  if $all_flag; then apply_all_abs 0; else set_brightness_abs 0; fi
  ;;
*)
  show_usage
  exit 1
  ;;
esac
