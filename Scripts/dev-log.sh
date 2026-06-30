#!/usr/bin/env bash
# Достаёт последние логи golos по категории hotkeys/coordinator и статусам разрешений.
log show --last 3m --predicate 'subsystem == "com.golos.app"' --info --debug 2>/dev/null \
  | grep -iE 'hotkey|perms|tap|flagsChanged|right-option|started|fail|error|coordinator' \
  | tail -60
