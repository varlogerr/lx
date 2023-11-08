TMP_LAUNCHER="$(mktemp)"
( chmod 0700 "${TMP_LAUNCHER}"
  grep -A9999 '.*#\s*{{\s*LXC_ACTION\s*\/}}\s*$' -- "${0}" \
  | sed '1 s/.*/#!\/usr\/bin\/env bash/' | tee -- "${TMP_LAUNCHER}" >/dev/null
)

export TPLS_URL
UPSTREAM="${0}" SHLIB_LOG_PREFIX="${SHLIB_LOG_PREFIX-$(
  basename -- "${0}"
): }" "${TMP_LAUNCHER}" "${@}"; RC=$?
(rm -f "${TMP_LAUNCHER}")

exit ${RC}
