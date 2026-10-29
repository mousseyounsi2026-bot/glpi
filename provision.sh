#!/usr/bin/env bash
# Provisioning GLPI 11 sur Debian 12 (bookworm) — idempotent pour un labo
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

GLPI_VERSION="${GLPI_VERSION:-11.0.4}"
DB_PASS="${DB_PASS:-Glpi-Lab-2026!}"

echo ">>> Paquets Apache / MariaDB / PHP"
apt-get update -qq
apt-get install -y -qq apache2 mariadb-server wget tar \
  php libapache2-mod-php php-cli php-mysql php-curl php-gd php-intl php-ldap \
  php-mbstring php-xml php-zip php-bz2 php-bcmath php-apcu

echo ">>> Réglages PHP"
PHPINI=$(php -r 'echo "/etc/php/".PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION."/apache2/php.ini";')
sed -i 's/^;\?session.cookie_httponly.*/session.cookie_httponly = On/' "$PHPINI"
sed -i 's/^;\?session.cookie_samesite.*/session.cookie_samesite = Lax/' "$PHPINI"
sed -i 's/^memory_limit.*/memory_limit = 256M/' "$PHPINI"
sed -i 's#^;\?date.timezone.*#date.timezone = Europe/Paris#' "$PHPINI"

echo ">>> Base de données (+ fuseaux horaires)"
mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | mysql mysql
mysql <<SQL
CREATE DATABASE IF NOT EXISTS glpi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'glpi'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost';
GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost';
FLUSH PRIVILEGES;
SQL

echo ">>> Téléchargement GLPI ${GLPI_VERSION}"
if [ ! -d /var/www/glpi ]; then
  wget -q "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz" -O /tmp/glpi.tgz
  tar -xzf /tmp/glpi.tgz -C /var/www/
fi
chown -R www-data:www-data /var/www/glpi

echo ">>> VirtualHost (DocumentRoot = public/)"
cat > /etc/apache2/sites-available/glpi.conf <<'EOF'
<VirtualHost *:80>
    ServerName glpi.local
    DocumentRoot /var/www/glpi/public
    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF
a2enmod -q rewrite
a2dissite -q 000-default
a2ensite -q glpi
systemctl restart apache2

echo ">>> Installation GLPI en ligne de commande (sans assistant web)"
cd /var/www/glpi
if [ ! -f config/config_db.php ]; then
  sudo -u www-data php bin/console db:install \
    --db-host=localhost --db-name=glpi --db-user=glpi --db-password="${DB_PASS}" \
    --default-language=fr_FR --no-interaction
fi
sudo -u www-data php bin/console database:enable_timezones || true
rm -f /var/www/glpi/install/install.php

echo ">>> Tâches planifiées GLPI"
echo "* * * * * www-data php /var/www/glpi/front/cron.php >/dev/null 2>&1" > /etc/cron.d/glpi

echo "======================================================"
echo " GLPI ${GLPI_VERSION} prêt : http://localhost:8080"
echo " Comptes par défaut : glpi/glpi, tech/tech, normal/normal, post-only/postonly"
echo " -> à changer immédiatement"
echo "======================================================"
