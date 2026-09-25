#!/usr/bin/env bash
# Pinned windows are neither tiled nor floating, so default pinned windows need
# to unpin to the correct tiling state based off of default floating. Also,
# default fullscreen and default scratchpad take precedence over default pinned. 
set -euo pipefail

spawn_client() {
  foot -T "$1" sh -c 'sleep 120' > /dev/null 2>&1 &
}

LINE_NUMBER=1
validate_log() {
  LINE=$(grep 'set_pinned' "$UMBRIEL_RUNTIME_DIR/compositor.log" | sed -n "${LINE_NUMBER}p")

  # Check that log was found if expected
  if [[ -z $LINE ]]; then
    if [[ $# > 0 ]]; then
      echo "Expected log but none received!"
      exit 1
    # If not expected, then no problem
    elif [[ $# == 0 ]]; then
      return 0
    fi
  else
    # If nothing expected, throw error
    if [[ $# == 0 ]]; then
      echo "No log expected, but one found anyways!"
      exit 1
    # Otherwise, increment to next line for next time
    else
      ((LINE_NUMBER++))
    fi
  fi

  if [[ ! "$LINE" =~ "$1" ]]; then
    echo "Expected $1, received: $LINE"
    exit 1
  elif [[ ! "$LINE" =~ "$2" ]]; then
    echo "Expected $2, received: $LINE"
    exit 1
  elif [[ ! "$LINE" =~ "$3" ]]; then
    echo "Expected $3, received: $LINE"
    exit 1
  elif [[ ! "$LINE" =~ "$4" ]]; then
    echo "Expected $4, received: $LINE"
    exit 1
  fi
}


cat >> "$UMBRIEL_CONFIG" <<'EOF'

[layout]
mode = "scrolling"

[[window_rule]]
match.title = "^pinned_and_floating$"
default_floating = true
default_pinned = true

[[window_rule]]
match.title = "^pinned_and_tiled$"
default_floating = false
default_pinned = true

[[window_rule]]
match.title = "^pinned_and_unset$"
default_pinned = true

[[window_rule]]
match.title = "^pinned_and_fullscreen$"
default_pinned = true
default_fullscreen = true

[[window_rule]]
match.title = "^pinned_and_scratchpad$"
default_pinned = true
default_scratchpad = "default"
EOF
"$UMBRIEL" msg config-reload > /dev/null

# ================== CASE 1: Default Floating ================== 
# Spawn first window & verify output
spawn_client "pinned_and_floating"
sleep "0.25s"
# Should be setting pinned to true but not currently pinned, as it's a new
# window. Since it's default_floating, restore_tiled should be false. 
validate_log "-> true" "tiled=false" "pinned=false" "restore_tiled=0"

# Toggle pinned & verify
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=0"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> true" "tiled=false" "pinned=false" "restore_tiled=undefined"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=0"

# Close the window
"$UMBRIEL" msg window-close

# ================== CASE 2: Default Tiled ================== 
# Spawn second window & verify output
spawn_client "pinned_and_tiled"
sleep "0.25s"
# Since this one is not default_floating, restore_tiled should be true. 
validate_log "-> true" "tiled=false" "pinned=false" "restore_tiled=1"

# Toggle pinned & verify
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=1"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> true" "tiled=true" "pinned=false" "restore_tiled=undefined"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=1"

# Close the window
"$UMBRIEL" msg window-close

# ================== CASE 3: Undefined Tiling ================== 
# Undefined should behave like a tiled window until pinning sets it otherwise.
spawn_client "pinned_and_unset"
sleep "0.25s"
validate_log "-> true" "tiled=true" "pinned=false" "restore_tiled=undefined"

# Toggle pinned & verify
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=1"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> true" "tiled=true" "pinned=false" "restore_tiled=undefined"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=1"

# Close the window
"$UMBRIEL" msg window-close

# ================== CASE 4: Fullscreen Override ================== 
# Fullscreen overrides pinned, so no output should be produced
spawn_client "pinned_and_fullscreen"
sleep "0.25s"
validate_log

# Close the window
"$UMBRIEL" msg window-close

# ================== CASE 5: Scratchpad Override ================== 
# Scratchpad overrides pinned, so no output should be produced
spawn_client "pinned_and_scratchpad"
sleep "0.25s"
validate_log

# Close the window
"$UMBRIEL" msg window-close

# ================== CASE 6: No Rules ================== 
# A window with no rules should simply behave like a normal tiled window
spawn_client "terminal"
sleep "0.25s"
validate_log

# Toggle pinned & verify
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> true" "tiled=true" "pinned=false" "restore_tiled=undefined"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=1"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> true" "tiled=true" "pinned=false" "restore_tiled=undefined"
"$UMBRIEL" msg window-toggle-pinned
sleep "0.25s"
validate_log "-> false" "tiled=false" "pinned=true" "restore_tiled=1"

# Close the window
"$UMBRIEL" msg window-close

echo "Pinned windows behaved as expected."
