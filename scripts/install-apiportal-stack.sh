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
