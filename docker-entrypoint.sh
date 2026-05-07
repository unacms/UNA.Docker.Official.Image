#!/bin/bash
set -eo pipefail

# function

qs() {
    if [[ $1 = /run/secrets/* ]]
    then
        result=`cat $1`
        echo ${result@Q}
    else
        echo ${1@Q}
    fi
}

# Unzip

if [ -n "${UNA_ZIP_DOWNLOAD_URL:-}" ] && [ -n "${UNA_ZIP_FOLDER:-}" ] && \
   [ ! -e "index.php" ] && [ ! -e "inc/version.inc.php" ]; then

    su "$UNA_USER" -c "
        set -eo pipefail;

        if [ \"${UNA_FOLDER_CLEANUP}\" = \"1\" ]; then
            find . -mindepth 1 -maxdepth 1 -exec rm -rf {} +;
        fi;

        curl -fSL \"${UNA_ZIP_DOWNLOAD_URL}\" -o una.zip;
        unzip -q una.zip;
        rm una.zip;

        mv \"${UNA_ZIP_FOLDER}\"/* .;
        mv \"${UNA_ZIP_FOLDER}/.htaccess\" .;
        rm -rf \"${UNA_ZIP_FOLDER}\";

        chmod 777 inc cache cache_public logs tmp storage;
        chmod +x plugins/ffmpeg/ffmpeg.exe;

        // find storage -exec chmod $UNA_USER:$UNA_USER {} \+ 
    "
fi

# Clean folders

rm -rf cache/* cache_public/* tmp/* 

# Change permissions

chmod +x plugins/ffmpeg/ffmpeg.exe
find . -exec chown $UNA_USER:$UNA_USER {} \+ || true

# Install

if [ -d "install" ] && [ ! -f "inc/header.inc.php" ]; then

    if [ -f /tmp/addon.sql ]; then
        echo "Found additional SQL file..."
        cat /tmp/addon.sql >> ./install/sql/addon.sql
    fi

    \cp -f /srv/header.inc.php install/patterns/ # make sure that old UNA version can work with ENV vars

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

# Crontab

if [[ ! -v UNA_NO_CRONTAB ]]; then
    echo "* * * * * /usr/local/bin/php -c /var/www /var/www/html/periodic/cron.php 2>&1 | sed -e \"s/\(.*\)/[\`date\`] \1/\" >>/var/www/cron.log" > /var/www/crontab
    chown $UNA_USER:$UNA_USER /var/www/crontab
    crontab -u $UNA_USER /var/www/crontab

    /etc/init.d/cron start
fi

#

exec "$@"
