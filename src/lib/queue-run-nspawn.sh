#!/usr/bin/env bash

function makepwd() {
  set -euo pipefail

  local _LS

  if [ ${#@} -eq 0 ]; then
    _LS=(./*/)
  else
    _LS=("$@")
  fi

  for _pkg in "${_LS[@]}"; do
    if [[ ! -d "${_pkg}" ]]; then
      echo "Skipping \"${_pkg}\", not a directory."
      continue
    elif [[ ! -f "${_pkg}/PKGBUILD" ]]; then
      echo "Skipping \"${_pkg}\", does not contains a PKGBUILD."
      continue
    fi
    (prepare "${_pkg}") || true # we want build to continue even if one pkg failed
  done

  for _pkg in "${_LS[@]}"; do
    [[ ! -f "${_pkg}/PKGTAG" ]] && continue
    (makepkg "${_pkg}" --noconfirm | tee "${_pkg}.log") \
      || true # we want to cleanup even if it failed
    (deploy "${_pkg}" && db-bump) || true
    (cleanup "${_pkg}") || true
  done

  return 0
}

function clean-logs() {
  set -euo pipefail

  local _TOREM

  mapfile -t _TOREM < <(grep -l -P 'ERROR: (A|The) package( group)? has already been built' ./*.log)
  [ ${#_TOREM[@]} -eq 0 ] || echo "${_TOREM[@]}" | xargs rm || true

  mapfile -t _TOREM < <(grep -l 'Finished making: ' ./*.log)
  [ ${#_TOREM[@]} -eq 0 ] || echo "${_TOREM[@]}" | xargs rm || true

  mapfile -t _TOREM < <(grep -l 'PKGBUILD does not exist.' ./*.log)
  [ ${#_TOREM[@]} -eq 0 ] || echo "${_TOREM[@]}" | xargs rm || true

  return 0
}
