#!/bin/bash
set -euox pipefail

UNA_USER="www-una"

VAR_DEF_DB_HOST="localhost"
VAR_DEF_DB_PORT="3306"
VAR_DEF_DB_USER="root"
VAR_DEF_DB_PWD="root"
VAR_DEF_HTTP_HOST="localhost"
VAR_DEF_TITLE="UNA"
VAR_DEF_USERNAME="admin"
VAR_DEF_ADMIN_PWD="admin"
VAR_DEF_EMAIL="admin@example.com"

VAR_DEF_DB_ENGINE="MYISAM"
VAR_DEF_AUTO_HOSTNAME=0

VAR_DEF_VERSION="13.0.0-RC5"
VAR_DEF_ZIP_DOWNLOAD_URL="http://ci.una.io/builds/UNA-v.${UNA_VERSION:-$VAR_DEF_VERSION}.zip"
VAR_DEF_ZIP_FOLDER="UNA-v.${UNA_VERSION:-$VAR_DEF_VERSION}"

# function

qs() { 
    echo ${1@Q}
}

# Unzip

if [ ! -e "index.php" ] && [ ! -e "inc/version.inc.php" ]; then
    su $UNA_USER -c "curl -fSL $(qs ${UNA_ZIP_DOWNLOAD_URL:-$VAR_DEF_ZIP_DOWNLOAD_URL}) -o una.zip"
    su $UNA_USER -c "unzip -o una.zip"
    su $UNA_USER -c "rm una.zip"
    su $UNA_USER -c "mv $(qs ${UNA_ZIP_FOLDER:-$VAR_DEF_ZIP_FOLDER})/* ."
    su $UNA_USER -c "mv $(qs ${UNA_ZIP_FOLDER:-$VAR_DEF_ZIP_FOLDER}/.htaccess) ."
    su $UNA_USER -c "rm -rf $(qs ${UNA_ZIP_FOLDER:-$VAR_DEF_ZIP_FOLDER})"
fi

# Clean folders

rm -rf cache/* cache_public/* tmp/*

# Change permissions

chmod +x plugins/ffmpeg/ffmpeg.exe
find . -exec chown $UNA_USER:$UNA_USER {} \+

# Install

if [ -d "install" ] && [ ! -f "inc/header.inc.php" ]; then
    su $UNA_USER -c "php ./install/cmd.php \
        --db_host=$(qs ${UNA_DB_HOST:-$VAR_DEF_DB_HOST}) \
        --db_port=$(qs ${UNA_DB_PORT:-$VAR_DEF_DB_PORT}) \
        --db_sock=$(qs ${UNA_DB_SOCK:-}) \
        --db_name=$(qs ${UNA_DB_NAME}) \
        --db_user=$(qs ${UNA_DB_USER:-$VAR_DEF_DB_USER}) \
        --db_password=$(qs ${UNA_DB_PWD:-$VAR_DEF_DB_PWD}) \
        --server_http_host=$(qs ${UNA_HTTP_HOST:-$VAR_DEF_HTTP_HOST}) \
        --server_php_self='/install/index.php' \
        --server_doc_root='/var/www/html/' \
        --site_title=$(qs ${UNA_SITE_TITLE:-$VAR_DEF_TITLE}) \
        --site_email=$(qs ${UNA_SITE_EMAIL:-$VAR_DEF_EMAIL}) \
        --admin_username=$(qs ${UNA_ADMIN_USERNAME:-$VAR_DEF_USERNAME}) \
        --admin_email=$(qs ${UNA_ADMIN_EMAIL:-$VAR_DEF_EMAIL}) \
        --admin_password=$(qs ${UNA_ADMIN_PWD:-$VAR_DEF_ADMIN_PWD}) \
        --oauth_key=$(qs ${UNA_KEY:-}) --oauth_secret=$(qs ${UNA_SECRET:-})"

    rm -rf ./install
fi

# Config alteration

if [ ${UNA_DB_ENGINE:-$VAR_DEF_DB_ENGINE} != "MYISAM" ]; then
    sed -r -i "s/^define\('BX_DATABASE_ENGINE', 'MYISAM'\);/define\('BX_DATABASE_ENGINE', '${UNA_DB_ENGINE:-$VAR_DEF_DB_ENGINE}'\);/g" /var/www/html/inc/header.inc.php
fi

if [ ${UNA_AUTO_HOSTNAME:-$VAR_DEF_AUTO_HOSTNAME} != 0 ]; then
    sed -r -i "s/^define\('BX_DOL_URL_ROOT', .*?;/define\('BX_DOL_URL_ROOT', \(\(isset\(\$_SERVER['HTTPS']\) \&\& \$_SERVER['HTTPS'] == 'on'\) || \(!empty\(\$_SERVER['HTTP_X_FORWARDED_PROTO']\) \&\& \$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https' || !empty\(\$_SERVER['HTTP_X_FORWARDED_SSL']\) \&\& \$_SERVER['HTTP_X_FORWARDED_SSL'] == 'on'\) ? 'https' : 'http'\) . ':\/\/' . \$_SERVER['HTTP_HOST'] . '\/'\);/g" /var/www/html/inc/header.inc.php
fi

# Crontab

if [[ ! -v UNA_NO_CRONTAB ]]; then
    echo "* * * * * /usr/local/bin/php -c /var/www /var/www/html/periodic/cron.php 2>&1 | sed -e \"s/\(.*\)/[\`date\`] \1/\" >>/var/www/cron.log" > /var/www/crontab
    chown $UNA_USER:$UNA_USER /var/www/crontab
    crontab -u $UNA_USER /var/www/crontab

    rm -f /etc/cron.d/sendmail
    /etc/init.d/cron start
fi

#

exec "$@"
