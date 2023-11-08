# Ensure some hard to reproduce and meaningless first arg for marker
[[ -n "${REMOTE_TARGET}" ]] && [[ "${1}" != 'REMOTE_<PjI:cL]E' ]] || {
  [[ "${1}" == 'REMOTE_<PjI:cL]E' ]] && shift
  return
}

#
# Launch on remote from local machine
#

REMOTE_ARGS=()
for arg in "${@}"; do
  # shellcheck disable=SC2001
  REMOTE_ARGS+=("\"$(sed 's/"/\\"/g' <<< "${arg}")\"")
done

# shellcheck disable=SC2016
# shellcheck disable=SC1004
echo '
  tmp="$(mktemp)"; chmod 0700 "${tmp}"
  base64 -d <<< "'"$(base64 -- "${0}")"'" > "${tmp}"

  SHLIB_LOG_PREFIX="'"$(basename -- "${0}"): "'" \
    "${tmp}" "REMOTE_<PjI:cL]E" '"${REMOTE_ARGS[*]}"'
  RC=$?

  rm -f "${tmp}"
  exit ${RC}
' | ssh "${REMOTE_TARGET}" bash -s

exit
