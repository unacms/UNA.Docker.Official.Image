#!/bin/bash
set -euox pipefail

# TODO: escape vars
# TODO: ability to restore from backup

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

VAR_DEF_VERSION="11.0.3"
VAR_DEF_ZIP_DOWNLOAD_URL="http://ci.una.io/builds/UNA-v.${UNA_VERSION:-$VAR_DEF_VERSION}.zip"
VAR_DEF_ZIP_FOLDER="UNA-v.${UNA_VERSION:-$VAR_DEF_VERSION}"

# Unzip

if [ ! -e "index.php" ] && [ ! -e "inc/version.inc.php" ]; then
    su $UNA_USER -c "curl -fSL ${UNA_ZIP_DOWNLOAD_URL:-$VAR_DEF_ZIP_DOWNLOAD_URL} -o una.zip"
    su $UNA_USER -c "unzip -o una.zip"
    su $UNA_USER -c "rm una.zip"
    su $UNA_USER -c "mv ${UNA_ZIP_FOLDER:-$VAR_DEF_ZIP_FOLDER}/* ."
    su $UNA_USER -c "mv ${UNA_ZIP_FOLDER:-$VAR_DEF_ZIP_FOLDER}/.htaccess ."
    su $UNA_USER -c "rm -rf ${UNA_ZIP_FOLDER:-$VAR_DEF_ZIP_FOLDER}"
fi

# Clean folders

rm -rf cache/* cache_public/* tmp/*

# Change permissions

chmod +x plugins/ffmpeg/ffmpeg.exe
find . -exec chown $UNA_USER:$UNA_USER {} \+

# Install

if [ -d "install" ] && [ ! -f "inc/header.inc.php" ]; then
    su $UNA_USER -c "php ./install/cmd.php \
        --db_host='${UNA_DB_HOST:-$VAR_DEF_DB_HOST}' \
        --db_port='${UNA_DB_PORT:-$VAR_DEF_DB_PORT}' \
        --db_sock='${UNA_DB_SOCK:-}' \
        --db_name='${UNA_DB_NAME}' \
        --db_user='${UNA_DB_USER:-$VAR_DEF_DB_USER}' \
        --db_password='${UNA_DB_PWD:-$VAR_DEF_DB_PWD}' \
        --server_http_host='${UNA_HTTP_HOST:-$VAR_DEF_HTTP_HOST}' \
        --server_php_self='/install/index.php' \
        --server_doc_root='/var/www/html/' \
        --site_title='${UNA_SITE_TITLE:-$VAR_DEF_TITLE}' \
        --site_email='${UNA_SITE_EMAIL:-$VAR_DEF_EMAIL}' \
        --admin_username='${UNA_ADMIN_USERNAME:-$VAR_DEF_USERNAME}' \
        --admin_email='${UNA_ADMIN_EMAIL:-$VAR_DEF_EMAIL}' \
        --admin_password='${UNA_ADMIN_PWD:-$VAR_DEF_ADMIN_PWD}' \
        --oauth_key='${UNA_KEY:-}' --oauth_secret='${UNA_SECRET:-}'"

    rm -rf ./install
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
