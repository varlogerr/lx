#!/usr/bin/env bash

# * Secret files are to be stored in /root/.secrets/lxc
#   * ${ID}.root.pass - root user password for machine ID.
#     Create with
#     ```sh
#     mkdir -p /root/.secrets/lxc
#     openssl passwd -5 "${PASS}" >/root/.secrets/lxc/${ID}.root.pass
#     ```
#     If preset doesn't find ${ID}.root.pass, it falls back to
#     master.root.pass ang then to master.pass
#
# * Each configuration section must:
#   * start with '\s*{.*'
#   * end with '}\s\+#\s*HOSTNAME=[^ ]\+\s*'
# * ID, TEMPLATE, UNPRIVILEGED and STORAGE are
#   required at creation. First three are immutable

# Templates list:
TPLS_URL=http://download.proxmox.com/images/system

# shellcheck disable=SC2034
{
  NAME=nas1.home
  ID=110
  TEMPLATE=ubuntu-22.04
  UNPRIVILEGED=1
  # ROOT_PASS=changeme # Handled by password preset
  STORAGE=local-lvm
  ONBOOT=1
  CORES=4
  MEMORY=4096
  DISK=15G
  # GATEWAY=192.168.0.1 # Handled by net preset
  # IP=192.168.0.10/24
  # USER_NAME=foo # Handled by user preset
  # USER_PASS=qwerty
  PRESETS=(password net user docker)
} # HOSTNAME=nas1.home

# shellcheck disable=SC2034
{
  NAME=servant1.home
  ID=110
  TEMPLATE=ubuntu-22.04
  UNPRIVILEGED=1
  # ROOT_PASS=changeme # Handled by password preset
  STORAGE=local-lvm
  ONBOOT=1
  CORES=2
  MEMORY=2048
  DISK=10G
  # GATEWAY=192.168.0.1 # Handled by net preset
  # IP=192.168.0.11/24
  # USER_NAME=foo # Handled by user preset
  # USER_PASS=qwerty
  PRESETS=(password net user docker vpn)
} # HOSTNAME=servant1.home

# shellcheck disable=SC2034
{
  NAME=servant2.home
  ID=110
  TEMPLATE=ubuntu-22.04
  UNPRIVILEGED=1
  # ROOT_PASS=changeme # Handled by password preset
  STORAGE=local-lvm
  ONBOOT=1
  CORES=2
  MEMORY=2048
  DISK=10G
  # GATEWAY=192.168.0.1 # Handled by net preset
  # IP=192.168.0.11/24
  # USER_NAME=foo # Handled by user preset
  # USER_PASS=qwerty
  PRESETS=(password net user docker vpn)
} # HOSTNAME=servant1.home

{ # Execute launcher
  TMP_LAUNCHER="$(mktemp)"
  ( chmod 0700 "${TMP_LAUNCHER}"
    grep -A9999 '.*#\s*{{\s*LXC_ACTION\s*\/}}\s*$' -- "${0}" \
    | sed '1 s/.*/#!\/usr\/bin\/env bash/' | tee -- "${TMP_LAUNCHER}" >/dev/null
  )

  export TPLS_URL
  UPSTREAM="${0}" SHLIB_LOG_PREFIX="$(basename -- "${0}"): " \
    "${TMP_LAUNCHER}" "${@}"; RC=$?
  (rm -f "${TMP_LAUNCHER}")

  exit ${RC}
} # Execute launcher

exit # {{ LXC_ACTION /}}

# shellcheck disable=SC2120
{ : # {{ SNIP_SHLIB }}
  # @.log
  # @text_fmt
  # @escape_sed_expr
  # @escape_sed_repl

  # Escape sed expression for basic regex.
  #
  # USAGE:
  #   escape_sed_expr FILE...
  #   escape_sed_expr <<< TEXT
  #
  # REFERENCES:
  #   * https://stackoverflow.com/a/2705678
  escape_sed_expr ()
  {
      {
          :
      };
      cat -- "${@}" | sed 's/[]\/$*.^[]/\\&/g'
  }

  # Escape sed replacement.
  #
  # USAGE:
  #   escape_sed_repl FILE...
  #   escape_sed_repl <<< TEXT
  #
  # REFERENCES:
  #   * https://stackoverflow.com/a/2705678
  escape_sed_repl ()
  {
      {
          :
      };
      cat -- "${@}" | sed 's/[\/&]/\\&/g'
  }

  # USAGE:
  #   [SHLIB_LOG_PREFIX] log_fuck FILE...
  #   [SHLIB_LOG_PREFIX] log_fuck <<< TEXT
  #
  # ENV:
  #   SHLIB_LOG_PREFIX  Custom log prefix, defaults to executor
  #                     filename (currently 'snippet.sh: ')
  log_fuck ()
  {
      {
          :
      };
      log_sth --what=FUCK -- "${@}"
  }

  # USAGE:
  #   [SHLIB_LOG_PREFIX] log_info FILE...
  #   [SHLIB_LOG_PREFIX] log_info <<< TEXT
  #
  # ENV:
  #   SHLIB_LOG_PREFIX  Custom log prefix, defaults to executor
  #                     filename (currently 'snippet.sh: ')
  log_info ()
  {
      {
          :
      };
      log_sth --what=INFO -- "${@}"
  }

  # Logger.
  #
  # USAGE:
  #   [SHLIB_LOG_PREFIX] log_sth [--what=''] FILE...
  #   [SHLIB_LOG_PREFIX] log_sth [--what=''] <<< TEXT
  #
  # ENV:
  #   SHLIB_LOG_PREFIX  Custom log prefix, defaults to executor
  #                     filename (currently 'snippet.sh: ')
  #
  # OPTIONS:
  #   --what  What to log
  #
  # DEMO:
  #   # Print with default prefix
  #   log_sth --what=ERROR 'Oh, no!' # STDERR: snippet.sh: [ERROR] Oh, no!
  log_sth ()
  {
      declare PREFIX;
      PREFIX="$(basename -- "${0}" 2>/dev/null)";
      PREFIX="${PREFIX:-snippet.sh}: ";
      {
          :
      };
      {
          declare -a ARG_FILE;
          declare -A OPT=([_endopts]=false [what]='');
          declare arg;
          while [[ -n "${1+x}" ]]; do
              ${OPT[_endopts]} && arg='*' || arg="${1}";
              case "${arg}" in
                  --)
                      OPT[_endopts]=true
                  ;;
                  --what=*)
                      OPT[what]="${1#*=}"
                  ;;
                  --what)
                      OPT[what]="${2}";
                      shift
                  ;;
                  *)
                      ARG_FILE+=("${1}")
                  ;;
              esac;
              shift;
          done
      };
      PREFIX="${SHLIB_LOG_PREFIX-${PREFIX}}";
      [[ -n "${OPT[what]}" ]] && PREFIX+="[${OPT[what]^^}] ";
      cat -- "${ARG_FILE[@]}" | text_prefix "${PREFIX}" 1>&2
  }

  # USAGE:
  #   [SHLIB_LOG_PREFIX] log_warn FILE...
  #   [SHLIB_LOG_PREFIX] log_warn <<< TEXT
  #
  # ENV:
  #   SHLIB_LOG_PREFIX  Custom log prefix, defaults to executor
  #                     filename (currently 'snippet.sh: ')
  log_warn ()
  {
      {
          :
      };
      log_sth --what=WARN -- "${@}"
  }

  # Format text.
  text_fmt ()
  {
      {
          :
      };
      declare text;
      text="$(cat -- "${@}")" || return;
      declare -i t_lines;
      t_lines="$(wc -l <<< "${text}")";
      declare -a rm_blanks=(grep -m1 -A "${t_lines}" -vx '\s*');
      text="$("${rm_blanks[@]}" <<< "${text}"     | tac | "${rm_blanks[@]}" | tac | grep '')" || return 0;
      declare offset;
      offset="$(sed -e '1!d' -e 's/^\(\s*\).*/\1/' <<< "${text}" | wc -m)";
      sed -e 's/^\s\{0,'$(( offset - 1 ))'\}//' -e 's/\s\+$//' <<< "${text}"
  }

  # Prefix text.
  #
  # USAGE:
  #   text_prefix PREFIX FILE...
  #   text_prefix [PREFIX=''] <<< TEXT
  #
  # DEMO:
  #   text_prefix '[pref] ' <<< 'My text.'  # STDOUT: [pref] My text.
  text_prefix ()
  {
      {
          :
      };
      declare prefix="${1}";
      declare escaped;
      escaped="$(escape_sed_expr <<< "${prefix}")";
      cat -- "${@:2}" | sed 's/^/'"${escaped}"'/'
  }
} # {{ SNIP_SHLIB }}

declare -A CONF; CONF=(
  # TODO: change to ${HOME}
  [secret_dir]=/root/.secrets/lxc
  [toolname]="$(basename -- "${UPSTREAM}")"
)

print_help() {
  echo "
    Deploy LXC container.

    USAGE:
      # View command help
      ${CONF[toolname]} COMMAND --help
      # Run command
      ${CONF[toolname]} COMMAND [ARG]...

    COMMANDS:
      deploy      Deploy lxc containers from deployment configuration
      demo-conf   Print LXC deployment configuration demo
      root-pass   Configure root password preset
      user        Configure user preset
  " | text_fmt
}

declare COMMAND
declare COMMAND_FUNC
declare -A COMMAND_TO_FNAME=(
  [deploy]=command_deploy
  [demo-conf]=command_demo_conf
  [root-pass]=command_root_pass
  [user]=command_user
)
parse_command() {
  case "${1}" in
    -\?|-h|--help ) print_help; exit ;;
    *             ) COMMAND="${1}" ;;
  esac

  [[ -n "${1+x}" ]] || {
    log_fuck <<< "COMMAND required."
    echo; print_help; return 2
  }

  [[ -n "${COMMAND_TO_FNAME[${COMMAND}]+x}" ]] || {
    log_fuck <<< "Unsupported COMMAND: '${COMMAND}'."
    echo; print_help; return 2
  }

  COMMAND_FUNC="${COMMAND_TO_FNAME[${COMMAND}]}"
}

print_demo_conf_help() {
  echo "
    Print LXC deployment configuration demo to stdout.

    USAGE:
      ${CONF[toolname]} ${COMMAND}
  " | text_fmt
}
command_demo_conf() {
  while [[ -n "${1+x}" ]]; do
    case "${1}" in
      -\?|-h|--help   ) print_demo_conf_help; exit ;;
    esac
    shift
  done

  echo "
    {
      # Requirements, limitations and guidance:
      # * Each configuration block must:
      #   * start with '^\s*{.*$'
      #   * end with '^.*}\s\+#\s*HOSTNAME=[^ ]\+\s*$'
      # * Variables don't override each other when they are in different blocks
      #   (see the list of supported vars below).
      # * Multiple blocks are allowed. That's one of the ways to keep multiple
      #   configurations in one file.
      # * Code outside configuration blocks is not evaluated for configuration.
      #   I.e. you can't factor out a common setting outside a configuration block.
      # * The following fields are required:
      #   * ID            - immutable after the container creation
      #   * TEMPLATE      - immutable after the container creation
      #   * UNPRIVILEGED  - immutable after the container creation
      #   * ROOT_PASS     - immutable after the container creation
      #
      # The basic idea of presets is:
      # * To hide some sensitive information about your infra. Same can be
      #   easily achieved with \`. <(cat CONTAINER_ID)\`.
      # * To simplify some configurations
      #
      # Available presets:
      # * password - configure container root password from a file in the
      #   filesystem. When enabled, ROOT_PASS is ignored. The password files
      #   (plain text or encoded with \`openssl passwd -5 \"\${PASS}\"\`) are
      #   search in the \${HOME}/.secrets/lxc directory with the following
      #   precedence: \"\${CONTAINER_ID}.root.pass\", \"master.root.pass\",
      #   \"root.pass\".
      # * net - same as password, but the searched files are
      #   \"\${CONTAINER_ID}.net.sh\", \"master.net.sh\", and \"net.sh\", and their
      #   contents is expected to be of 2 optional variables IP=\"...\" and
      #   GATEWAY=\"...\". You can declare more, but it's it's better to keep the
      #   convention. It's convenient to declare IP in the container file and
      #   GATEWAY in 'net.sh' to avoid duplication.
      # * net - same as 'password', but the searched files are
      #   \"\${CONTAINER_ID}.net.sh\", \"master.net.sh\", and \"net.sh\", and their
      #   contents is expected to be of 2 optional variables IP=\"...\" and
      #   GATEWAY=\"...\". You can declare more, but it's it's better to keep the
      #   convention. It's convenient to declare IP in the container file and
      #   GATEWAY in 'net.sh' to avoid duplication.
      # * user - same as with 'net', file suffix is \"user.sh\", expected vars are:
      #   USER_NAME, USER_PASS, USER_GROUP, USER_HOME. USER_PASS value can be
      #   encrypted or plain text.
      # * docker - configures the container to work with containers, no additional
      #   settings on the file system level. It manipulates lxc conf files.
      # * vpn - same as 'docker', but configures for VPN server.
      #
      NAME=sendbox.portal.local
      ID=169
      TEMPLATE=ubuntu-22.04
      UNPRIVILEGED=1
      ROOT_PASS=changeme    # Can be overriden by 'password' preset
      STORAGE=local-lvm
      ONBOOT=1
      CORES=4
      MEMORY=4096
      DISK=15G
      GATEWAY=192.168.0.1   # Can be overriden by 'net' preset
      IP=192.168.0.69/24
      USER_NAME=foo         # Can be overriden by 'user' preset
      USER_PASS=qwerty
      PRESETS=(docker vpn)
    } # HOSTNAME=sendbox.portal.local
  " | text_fmt
}

parse_command "${@}" || exit
"${COMMAND_FUNC}" "${@:2}"


exit

{ # Helpers
  download() {
    declare url="${1}"
    declare dest="${2--}"
    declare -a tool=(curl -kLsS)

    "${tool[@]}" --version &>/dev/null && {
      tool+=(-o "${dest}")
    } || {
      tool=(wget -q); "${tool[@]}" --version &>/dev/null \
      && tool+=(-O "${dest}")
    } || {
      log_fuck <<< "Can't detect download tool."
      return 1
    }

    (set -x; "${tool[@]}" -- "${url}")
  }
} # Helpers

{ # Stages
  tpl_cache() {
    declare -gA TPLS_CACHE

    [[ -n "${TPLS_CACHE[${TEMPLATE}]}" ]] || {
      declare tpl_expr; tpl_expr="$(escape_sed_expr <<< "${TEMPLATE}")"
      declare tpls_url_repl; tpls_url_repl="$(escape_sed_repl <<< "${TPLS_URL}")"

      log_info <<< "Getting download URL for template: '${TEMPLATE}'."
      declare tpl_url; tpl_url="$(set -o pipefail
        download "${TPLS_URL}" \
          | sed -n 's/.*href="\('"${tpl_expr}"'[^"]*\.tar\.\(gz\|xz\|zst\)\)".*/\1/p' \
          | sort -V | tail -n 1 | grep '' | sed 's/^/'"${tpls_url_repl}"'\//'
      )" || {
        log_fuck <<< "Can't detect download URL."
        return 1
      }

      log_info <<< "Downloading template: '${TEMPLATE}'."
      declare tmp; tmp="$(mktemp --suffix "-${tpl_url##*/}")" || {
        log_fuck <<< "Can't create tmp file."
        return 1
      }

      download "${tpl_url}" "${tmp}" || {
        log_fuck <<< "Can't download template."
        return 1
      }

      TPLS_CACHE["${TEMPLATE}"]="${tmp}"
    }
  }

  clean_tmp() {
    [[ ${#TPLS_CACHE[@]} -gt 0 ]] && (set -x; rm -f "${TPLS_CACHE[@]}")
  }
} # Stages

{ # Presets
  preset_password() {
    unset -v ROOT_PASS

    declare pass; pass="$(
      set -x
      cd -- "${CONF[secret_dir]}" && {
        cat -- "${ID}.root.pass" 2>/dev/null \
        || cat -- "master.root.pass" 2>/dev/null \
        || cat -- "master.pass" 2>/dev/null
      }
    )" || {
      log_fuck <<< "Can't read password file."
      return 1
    }

    ROOT_PASS="${pass}"; return 0
  }

  trap_preset() {
    [[ " ${PRESETS[*],,} " == *" ${1,,} "* ]] || return 0

    declare callback="preset_${1}"
    "${callback}"
  }
} # Presets

CONF_PART="$(grep -B999 '.*#\s*{{\s*LXC_ACTION\s*\/}}\s*$' -- "${UPSTREAM}" | sed '$ d')"

CONF_BLOCKS_TXT="$(
  grep -n '}\s\+#\s*HOSTNAME=[^ ]\+\s*$' <<< "${CONF_PART}" \
  | grep -o '^[0-9]\+' | tac | while read -r line; do
    echo '---'
    head -n "${line}" <<< "${CONF_PART}" | tac \
    | grep -m 1 -x -B999 '\s*{.*' | tac | sed -e '1 d' -e '$ d' | tac
  done | tac
)"

declare -a CONF_BLOCKS
while b_end="$(grep -m1 -nx -- '---' <<< "${CONF_BLOCKS_TXT}" | grep -o '^[0-9]\+')"; do
  CONF_BLOCKS+=("$(head -n "$(( b_end - 1 ))" <<< "${CONF_BLOCKS_TXT}")")
  CONF_BLOCKS_TXT="$(tail -n +"$(( b_end + 1 ))" <<< "${CONF_BLOCKS_TXT}")"
done

pveversion &>/dev/null || { log_fuck <<< "Can't detect PVE."; exit 1; }
[[ ${#CONF_BLOCKS[@]} -gt 0 ]] || { log_fuck <<< "No configurations found."; exit 1; }

(
  for block in "${CONF_BLOCKS[@]}"; do
    # Ensure configuration doesn't come from environment or previous iteration
    unset -v NAME TEMPLATE ID UNPRIVILEGED PASSWORD \
      STORAGE ONBOOT CORES MEMORY DISK GATEWAY IP HOOKS

    # shellcheck disable=SC1090
    . <(echo "${block}")

    # Check LXC id already in use
    id_expr="$(escape_sed_expr <<< "${ID}")"
    if pct list | sed '1 d' | grep -q "^${id_expr}[^0-9]"; then
      log_info <<< "LXC already exists: '${ID}'."
    else
      # Exports TPLS_CACHE
      tpl_cache
      trap_preset password

      (set -x;
        # Always leave password in the very end for obfuscation
        pct create "${ID}" \
          "${TPLS_CACHE[$TEMPLATE]}" \
          -storage "${STORAGE}" \
          -unprivileged "${UNPRIVILEGED}" \
          -password "${ROOT_PASS}"
      ) 3>&2 2>&1 1>&3 \
      | sed 's/\(\s-password\)\( .\+\)/\1 *****/' 3>&2 2>&1 1>&3
    fi
  done

  clean_tmp
)
