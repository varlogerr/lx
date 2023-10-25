declare -a REPOS_RHEL; REPOS_RHEL=(
  "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E '%{rhel}').noarch.rpm"
)
declare -a PKGS_RHEL=(neovim)
declare -a PKGS_DEB=(nvim)
declare -a PKGS=(
  bash-completion
  curl
  htop
  nano
  tar
  tmux
  gzip
  tree
  vim
  wget
)

declare PM
{
  PM=apt; ${PM} --version &>/dev/null
} || [[ $? -lt 3 ]] || {
  PM=dnf; ${PM} --version &>/dev/null
} || [[ $? -lt 3 ]] || {
  echo "install-gp-client [FUCK]: Can't detect PM." >&2
  return 1
}

[[ "${PM}" == "apt" ]] && {
  PKGS+=("${PKGS_DEB[@]}")
  (set -x; apt update)
}
[[ "${PM}" == "dnf" ]] && {
  PKGS+=("${PKGS_RHEL[@]}")
  (set -x; dnf install -y "${REPOS_RHEL[@]}")
}

(set -x; "${PM}" install -y "${PKGS[@]}")
