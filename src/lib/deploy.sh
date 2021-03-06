#!/usr/bin/env bash

function deploy() {
  set -euo pipefail

  local _INPUTDIR _RESULT

  _INPUTDIR="$(
    cd "${1:-}"
    pwd -P
  )"

  _RESULT="${_INPUTDIR}/building.result"

  if [[ -z "${CAUR_SIGN_KEY}" ]]; then
    echo 'A signing key is required for deploying.'
    return 17
  elif [[ ! -e "${_RESULT}" ]] \
    || [[ "$(cat "${_RESULT}")" != 'success' ]]; then
    echo 'Invalid package, last build did not succeed, or aready deployed.'
    return 18
  fi

  pushd "${_INPUTDIR}/dest"
  chown "${CAUR_SIGN_USER}" .
  for f in !(*.sig); do
    [[ "$f" == '!(*.sig)' ]] && continue

    if [[ ! -e "${f}.sig" ]]; then
      sudo -u "${CAUR_SIGN_USER}" \
        /usr/bin/gpg --detach-sign \
        --use-agent -u "${CAUR_SIGN_KEY}" \
        --no-armor "$f"
    fi

    if [[ "$CAUR_TYPE" == 'cluster' ]]; then
      scp "$f"{,.sig} "${CAUR_ADD_DEST}/"
    else
      cp -v "$f"{,.sig} "${CAUR_DEST_PKG}/"
    fi
  done
  popd # "${_INPUTDIR}/dest"

  echo 'deployed' >"${_RESULT}"

  return 0
}

function deploypwd() {
  set -euo pipefail

  local _LS

  if [ ${#@} -eq 0 ]; then
    _LS=(./*/)
  else
    _LS=("$@")
  fi

  if [[ -z "${CAUR_SIGN_KEY}" ]]; then
    echo 'A signing key is required for deploying.'
    return 17
  fi

  for _pkg in "${_LS[@]}"; do
    (deploy "$_pkg") || continue
  done

  return 0
}
