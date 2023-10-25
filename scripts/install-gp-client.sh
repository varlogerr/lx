declare PM EXT
{
  EXT=deb
  PM=apt; ${PM} --version &>/dev/null
} || [[ $? -lt 3 ]] || {
  EXT=rpm
  PM=dnf; ${PM} --version &>/dev/null
} || [[ $? -lt 3 ]] || {
  echo "install-gp-client [FUCK]: Can't detect PM." >&2
  return 1
}

(set -x; systemctl status gpd &>/dev/null) || {
  declare DL_URL=https://raw.githubusercontent.com/varlogerr/lx/master/assets/gp-client.tar.gz
  declare TMP; TMP="$(mktemp -d)"

  [[ ${PM} == apt ]] && (set -x; ${PM} update)
  (set -x \
    && ${PM} install -y tar gzip \
    && set -x; curl --fail -skL "${DL_URL}" | tar -C "${TMP}" -xzf - \
    && ${PM} install -y "${TMP}"/*."${EXT}"
  )

  (set -x; rm -rf "${TMP}")
}

