declare PM
{
  PM=apt; ${PM} --version &>/dev/null
} || [[ $? -lt 3 ]] || {
  PM=dnf; ${PM} --version &>/dev/null
} || [[ $? -lt 3 ]] || {
  echo "install-ssh [FUCK]: Can't detect PM." >&2
  return 1
}

(set -x; systemctl status sshd &>/dev/null) || {
  [[ ${PM} == apt ]] && (set -x; ${PM} update)
  (set -x \
    && ${PM} install -y openssh-server \
    && systemctl enable --now sshd
  )
}
