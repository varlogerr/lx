declare PHP_V=8.1
declare -a REPOS; REPOS=(
  "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E '%{rhel}').noarch.rpm"
  "https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E '%{rhel}').rpm"
)
declare -a LAMP=(
  mariadb-server
  httpd mod_ssl
  php php-cli php-gd php-intl php-mbstring php-mcrypt
  php-mysqlnd php-pecl-redis5 php-pecl-zip php-pdo php-xml
)

declare php_v_rex; php_v_rex="$(sed 's/\./\\./' <<< "${PHP_V}")"

(set -x
  php --version 2>/dev/null | head -n 1 | grep -q "${php_v_rex}\\.[0-9]\\+" \
  && systemctl status mariadb &>/dev/null \
  && systemctl status httpd &>/dev/null
) || (set -x
  curl --fail -skL https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash \
  && dnf install -y "${REPOS[@]}" \
  && dnf module reset -y php \
  && dnf module install -y php:remi-${PHP_V} \
  && dnf install -y "${LAMP[@]}" \
  && systemctl enable --now mariadb httpd
)

echo "LoadModule mpm_prefork_module modules/mod_mpm_prefork.so" \
| (set -x; tee /etc/httpd/conf.modules.d/*mpm.conf >/dev/null)

create_user() {
  declare user="${1}"
  declare password; password="${2-$(timeout 1 cat -)}"

  [[ (-n "${user}" && -n "${password}")]] || {
    echo "USAGE:" >&2
    echo "  ${0} USER PASSWORD" >&2
    echo "  ${0} USER <<< PASSWORD" >&2
    exit 2
  }

  mariadb -uroot <<< "
    CREATE USER '${user}'@'localhost' IDENTIFIED BY '${password}';
    CREATE USER '${user}'@'%' IDENTIFIED BY '${password}';
    GRANT ALL PRIVILEGES ON *.* TO '${user}'@'localhost' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON *.* TO '${user}'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  "
}

mkdir -p ~/bin
(set -x; touch ~/bin/db-mkuser.sh && chmod +x ~/bin/db-mkuser.sh)
(set -x; {
  declare -f create_user
  # shellcheck disable=SC2016
  echo 'create_user "${@}"'
} | tee ~/bin/db-mkuser.sh >/dev/null)
