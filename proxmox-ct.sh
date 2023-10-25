#!/usr/bin/env bash

{ # {{ CONFBLOCK }}
  declare DEST=root@192.168.69.5

  declare -A CT_CONF_AXWAY_INT1; CT_CONF_AXWAY_INT1=(
    #
    # Init only
    #
    [template]='almalinux-8'  # List: http://download.proxmox.com/images/system
    [id]=131
    [unprivileged]=0
    [password]='changeme'
    [storage]='S1TB'
    #
    # Changeable
    #
    [hostname]='int1.axway.vm'
    [onboot]=1                # Example: '0' or '1'
    [cores]='2'               # Example: '1' or '69'
    [memory]='2048'           # Example: '512'
    [disk]='10G'              # Example: '8G'
    [gateway]='192.168.69.1'  # Example: '192.168.0.1'
    [ip]='192.168.69.31/24'   # Example: '192.168.0.10/24'
    [dev_net]=1               # Mount dev/net, vpn friendly. Example: '0' or '1'
    [after]='
      install_goodies
      install_ssh
      install_gp_client
      install_apiportal_stack
    '
  )

  install_goodies() (set -x; curl --fail -kL "https://raw.githubusercontent.com/varlogerr/lx/master/scripts/install-goodies.sh" | bash)
  install_ssh() (set -x; curl --fail -kL "https://raw.githubusercontent.com/varlogerr/lx/master/scripts/install-ssh.sh" | bash)
  install_gp_client() (set -x; curl --fail -kL "https://raw.githubusercontent.com/varlogerr/lx/master/scripts/install-gp-client.sh" | bash)
  install_apiportal_stack() (set -x; curl --fail -kL "https://raw.githubusercontent.com/varlogerr/lx/master/scripts/install-apiportal-stack.sh" | bash)
} # {{/ CONFBLOCK }}

################
#### ACTION ####
################

{ # {{ DEMOBLOCK }}
  #
  # Copy this block, remove 'DEMO_' prefix and add
  # suffix
  #

  # Target machine
  declare DEMO_DEST=root@192.168.0.5

  declare -A DEMO_CT_CONF; DEMO_CT_CONF=(
    #
    # Init only
    #
    [template]='ubuntu-22.04' # List: http://download.proxmox.com/images/system
    [id]=110
    [unprivileged]=1          # Use '0' for alternative to 'docker' preset
    [password]='changeme'
    [storage]='local-lvm'
    #
    # Changeable
    #
    [hostname]='demo'
    [onboot]=0                # Example: '0' or '1'
    [cores]=''                # Example: '1' or '69'
    [memory]=''               # Example: '512'
    [disk]=''                 # Example: '8G'
    [gateway]=''              # Example: '192.168.0.1'
    [ip]=''                   # Example: '192.168.0.10/24'
    [dev_net]=0               # Mount dev/net. Example: '0' or '1'
    [docker]=0                # Docker ready, better than privileged. Example: '0' or '1'
    [after]=''                # After hooks, one hook script per line. Launched in the container
  )
} # {{/ DEMOBLOCK }}

declare CT_CONFDIR=/etc/pve/lxc
declare TPLS_URL=http://download.proxmox.com/images/system
declare SELF; SELF="${BASH_SOURCE[0]}"

_ct_conf_update() {
  declare -a updates=("${@}")
  declare CONFFILE="${CT_CONFDIR}/${THE_CONF[id]}.conf"

  # Clean and unify update lines
  declare UPDATE; UPDATE="$(
    printf -- '%s\n' "${updates[@]}" | sed -e '/^\s*$/d' \
      -e 's/^\s*//' -e 's/\s*$//' -e 's/^\([^:= ]\+\)\s*[:=]/\1:/'
  )"
  declare UPDATE_REX; UPDATE_REX="$(
    _escape_sed_expr <<< "${UPDATE}" | sed -e 's/\s\+/\\s\\+/g' \
      -e 's/^/^\\s*/' -e 's/$/\\s*$/'
  )"

  declare BLOCK_ENDLINE; BLOCK_ENDLINE="$(
    set -o pipefail
    grep -n -m1 -B999999 '\s*[^\]]\+\s*' -- "${CONFFILE}" 2>/dev/null \
    | tail -n 2 | sed -n '1 s/^\([0-9]\+\).*/\1/p'
  )" || [[ $? -lt 2 ]] || {
    _log_warn "Can't get current confblock in '${CONFFILE}'."
    return 1
  }

  declare CONFBLOCK; CONFBLOCK="$(cat -- "${CONFFILE}")"
  [[ -n "${BLOCK_ENDLINE}" ]] && CONFBLOCK="$(head -n "${BLOCK_ENDLINE}" -- "${CONFFILE}")"

  CONFBLOCK="$(grep -vf <(cat <<< "${UPDATE_REX}") <<< "${CONFBLOCK}")"$'\n'"${UPDATE}"

  declare tail
  [[ -n "${BLOCK_ENDLINE}" ]] && tail="$(tail -n +"${BLOCK_ENDLINE}" -- "${CONFFILE}")"

  printf -- '%s\n' "${CONFBLOCK}${tail+$'\n'}${tail}" \
  | (set -x; tee -- "${CONFFILE}") >/dev/null
}

ct_conf_devnet() {
  [[ ${THE_CONF[dev_net]} -gt 0 ]] || return 0

  _log_info 'Mount /dev/net'

  # https://pve.proxmox.com/wiki/OpenVPN_in_LXC
  _ct_conf_update "
    # VPN server ready
    lxc.mount.entry: /dev/net dev/net none bind,create=dir 0 0
    lxc.cgroup2.devices.allow= c 10:200 rwm
  "
}

ct_conf_docker() {
  [[ ${THE_CONF[docker]} -gt 0 ]] || return 0

  _log_info 'Docker ready'

  # https://gist.github.com/varlogerr/9805998a6ac9ad4fa930a07951e9a3dc
  _ct_conf_update "
    # Docker ready
    lxc.apparmor.profile: unconfined
    lxc.cgroup2.devices.allow: a
    lxc.cap.drop:
  "
}

ct_create() {
  declare id_rex; id_rex="$(_escape_sed_expr "${THE_CONF[id]}")"
  pct list | tail -n +2 | grep -q "^${id_rex}[^0-9]" && {
    _log_info "CT '${THE_CONF[id]}' already exists. Skipping creation."
    return 0
  }

  # Detect template file
  declare tpl_rex; tpl_rex="$(_escape_sed_expr "${THE_CONF[template]}")"
  declare tpl_filename; tpl_filename="$(
    set -o pipefail
    (set -x; curl --fail -skL "${TPLS_URL}" \
      | sed -n 's/.*href="\('"${tpl_rex}"'[^"]*\.tar\.\(gz\|xz\|zst\)\)".*/\1/p'
    ) | sort -V | tail -n 1 | grep ''
  )" || { _log_warn "Can't detect template. Skipping the CT."; return 1; }

  # Create tmp file
  THE_CONF[tpl_file]="$(set -x; mktemp --suffix "-${tpl_filename}")" || {
    _log_warn "Can't create tmp download file. Skipping the CT."; return 1
  }

  declare -i RC=0

  # Download template
  (set -x; curl --fail -skL "${TPLS_URL}/${tpl_filename}" -o "${THE_CONF[tpl_file]}") || {
    RC=$?; _log_warn "Can't download template. Skipping the CT."
  }

  [[ ${RC} -gt 0 ]] || (set -x
    pct create \
      "${THE_CONF[id]}" \
      "${THE_CONF[tpl_file]}" \
      -password "${THE_CONF[password]}" \
      -storage "${THE_CONF[storage]}" \
      -unprivileged "${THE_CONF[unprivileged]}"
  ) || { RC=$?; _log_warn "Can't create CT. Skipping the CT."; }

  (set -x; rm -f "${THE_CONF[tpl_file]}")

  return ${RC}
}

ct_conf_basic() {
  # Update hostname
  (set -x; pct set "${THE_CONF[id]}" -hostname "${THE_CONF[hostname]}") \
  || _log_warn "Can't update 'hostname'."

  # Update memory and cores
  declare t; for t in onboot memory cores; do
    [[ -z "${THE_CONF[$t]}" ]] \
    && _log_info "No configuration for '${t}'. Skipping." \
    || (set -x; pct set "${THE_CONF[id]}" -${t} "${THE_CONF[$t]}") \
    || _log_warn "Can't update '${t}'."
  done

  # Update network
  [[ ! (-n "${THE_CONF[gateway]}" || -n "${THE_CONF[ip]}") ]] \
  && _log_info "No configuration for network. Skipping." \
  || (
    declare confline='name=eth0,bridge=vmbr0,firewall=1'
    confline+="${THE_CONF[gateway]:+,gw=${THE_CONF[gateway]}}"
    confline+="${THE_CONF[ip]:+,ip=${THE_CONF[ip]}}"

    set -x
    pct set "${THE_CONF[id]}" -net0 "${confline}"
  ) || { _log_warn "Can't update network."; }

  # Update disk size
  [[ -z "${THE_CONF[disk]}" ]] \
  && _log_info "No configuration for disk. Skipping." \
  || (set -x; pct resize "${THE_CONF[id]}" rootfs "${THE_CONF[disk]}") \
  || _log_warn "Can't update 'disk'."
}

ct_after_hooks() {
  declare hooks_txt
  hooks_txt="$(set -o pipefail
    sed -e 's/^\s\+//' -e '/^\s*$/d' -e '/^#/d' <<< "${THE_CONF[after]}" | grep ''
  )" || return 0

  declare -a HOOKS_ORDERED
  mapfile -t HOOKS_ORDERED <<< "${hooks_txt}"

  # Map hook names to definitions
  declare -A NAME2DEF
  declare def
  declare name; for name in "${HOOKS_ORDERED[@]}"; do
    def="$(declare -f "${name}" 2>/dev/null)" \
    && { NAME2DEF[$name]="${def}"; continue; }

    _log_warn "Can't parse hook: '${name}'"
  done

  # Nothing to do if no parsed hooks
  [[ ${#NAME2DEF[@]} -gt 0 ]] || return 0

  # Detect is current state is 'running'
  declare WAS_RUNNING
  pct status "${THE_CONF[id]}" | grep -q 'running$' \
  && WAS_RUNNING=true || WAS_RUNNING=false

  if ! ${WAS_RUNNING}; then
    # Boot the CT
    (set -x
      pct start "${THE_CONF[id]}"
      lxc-wait "${THE_CONF[id]}" --state="RUNNING" -t 10
    ) || {
      _log_warn "Failed to start the CT. Skipping."
      (set -x; pct stop "${THE_CONF[id]}"); return 0
    }
  fi

  # Give it 5 seconds to warm up the services
  declare uptime; uptime="$(pct exec "${THE_CONF[id]}" -- bash -c \
    '(set -x; grep -o "^[0-9]\\+" /proc/uptime 2>/dev/null)')"
  [[ "${uptime:-0}" -lt 5 ]] && sleep $(( 5 - "${uptime:-0}" ))

  # Run hooks
  declare name; for name in "${HOOKS_ORDERED[@]}"; do
    [[ -n "${NAME2DEF[$name]}" ]] || continue

    _log_info
    _log_info "#### HOOK: ${name} ####"
    _log_info
    printf -- '%s; %s' "${NAME2DEF[$name]}" "${name}" \
    | (set -x; pct exec "${THE_CONF[id]}" bash)
  done

  # Shut down the CT only if it was not running
  ! ${WAS_RUNNING} && (set -x; pct stop "${THE_CONF[id]}")
}

run_self_remotely() {
  # Remove local marker
  grep -q '# {{ IS_LOCAL=true \/}}$' "${SELF}" 2>/dev/null && {
    ssh "${DEST}" bash -s < <(
      grep -v '# {{ IS_LOCAL=true \/}}$' "${SELF}"
    )
  }

  exit 0 # {{ IS_LOCAL=true /}}
}

_log_info() { printf -- 'proxmox-ct.sh [%s]: %s\n' INFO "${1}" >&2; }
_log_warn() { printf -- 'proxmox-ct.sh [%s]: %s\n' WARN "${1}" >&2; }
_log_fuck() { printf -- 'proxmox-ct.sh [%s]: %s\n' FUCK "${1}" >&2; }

# https://stackoverflow.com/a/2705678
_escape_sed_expr()  { sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"; }
_escape_sed_repl()  { sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"; }

main() {
  run_self_remotely

  declare tmp; tmp="$(
    set -o posix; set | grep '^CT_CONF' | cut -d'=' -f1 \
    | while read -r v; do
      [[ "$(declare -p "${v}" 2>/dev/null)" == "declare -A"* ]] || continue
      echo "${v}"
    done
  )"

  [[ -n "${tmp}" ]] || {
    _log_fuck "No CT configuration detected, check CT_CONF vars."
    exit 2
  }

  declare -a conf_vars; mapfile -t conf_vars <<< "${tmp}"

  declare -A THE_CONF
  declare conf_key
  declare v; for v in "${conf_vars[@]}"; do
    eval "$(declare -pA "${v}" | sed 's/^[^=]\+/THE_CONF/')"

    # Configure defaults
    for conf_key in "${!DEMO_CT_CONF[@]}"; do
      THE_CONF["${conf_key}"]="${THE_CONF[${conf_key}]:-${DEMO_CT_CONF[${conf_key}]}}"
    done

    ct_create \
    && {
      ct_conf_basic
      ct_conf_devnet
      ct_conf_docker
      ct_after_hooks
    }
  done
}

main
