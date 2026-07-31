#!/bin/bash
set -eo pipefail

# function

file_env() {
    local var="$1"
    local fileVar="${var}_FILE"

    if [ -n "${!var:-}" ] && [ -n "${!fileVar:-}" ]; then
        echo "Both $var and $fileVar are set, but are exclusive"
        exit 1
    fi

    local val=""

    if [ -n "${!var:-}" ]; then
        val="${!var}"
    elif [ -n "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi

    if [ -n "$val" ]; then
        export "$var"="$val"
    fi

    unset "$fileVar"
}

# expand secrets

file_env UNA_DB_PWD
file_env UNA_ADMIN_PWD
file_env UNA_KEY
file_env UNA_SECRET
file_env UNA_HASH_SECRET
file_env UNA_DEBUG_COOKIE

# Mainenance page 

MAINTENANCE_DIR="/tmp/maintenance"
mkdir -p $MAINTENANCE_DIR
chmod 777 $MAINTENANCE_DIR
echo '' > $MAINTENANCE_DIR/status.txt
chmod 666 $MAINTENANCE_DIR/status.txt
cat > $MAINTENANCE_DIR/index.php <<'EOF'
<?php
http_response_code(503);
header('Retry-After: 10');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Pragma: no-cache');

if (str_contains($_SERVER['REQUEST_URI'], 'status')) {
    $file = '/tmp/maintenance/status.txt';
    if (is_file($file)) {
        header('Content-Type: text/plain');
        readfile($file);
        exit;
    }
}

header('Content-Type: text/html; charset=utf-8');
?>
<h1>🚀 Starting UNA...</h1>
<p id="status"></p>
<script>
    setTimeout(()=>location.reload(), 3000);
    var f = async () => {
    	let r = await fetch('status.txt', { cache: 'no-store' });
    	document.getElementById('status').innerHTML = await r.text();
    };
    setTimeout(f, 0);
    setInterval(f, 1000);
</script>
EOF

php -S 0.0.0.0:80 $MAINTENANCE_DIR/index.php &
PID_PHP=$!

# Unzip

if [ -n "${UNA_ZIP_DOWNLOAD_URL:-}" ] && [ -n "${UNA_ZIP_FOLDER:-}" ] && \
   [ ! -e "index.php" ] && [ ! -e "inc/version.inc.php" ]; then

    su "$UNA_USER" -c "
        set -eo pipefail;

        echo 'Downloading...' > $MAINTENANCE_DIR/status.txt

        if [ \"${UNA_FOLDER_CLEANUP}\" = \"1\" ]; then
            find . -mindepth 1 -maxdepth 1 -exec rm -rf {} +;
        fi;

        echo 'Unzipping...' > $MAINTENANCE_DIR/status.txt

        curl -fSL \"${UNA_ZIP_DOWNLOAD_URL}\" -o una.zip;
        unzip -q una.zip;
        rm una.zip;

        mv \"${UNA_ZIP_FOLDER}\"/* .;
        mv \"${UNA_ZIP_FOLDER}/.htaccess\" .;
        rm -rf \"${UNA_ZIP_FOLDER}\";

        chmod 777 inc cache cache_public logs tmp storage;
        chmod +x plugins/ffmpeg/ffmpeg.exe;

        find storage -type f -exec chmod 666 {} \+;
        find storage -type d -exec chmod 777 {} \+;
    "
fi

# Clean folders

rm -rf cache/* cache_public/* tmp/*

# Change permissions

chmod +x plugins/ffmpeg/ffmpeg.exe
find . -exec chown $UNA_USER:$UNA_USER {} \+ || true

# Install

if [ -d "install" ] && [ ! -f "inc/header.inc.php" ]; then

    echo 'Installing...' > $MAINTENANCE_DIR/status.txt

    if [ -f /tmp/addon.sql ]; then
        echo "Found additional SQL file..."
        cat /tmp/addon.sql >> ./install/sql/addon.sql
    fi

    \cp -f /srv/header.inc.php install/patterns/ # make sure that old UNA version can work with ENV vars

    INSTALL_CMD=(
        php ./install/cmd.php
        --db_host="${UNA_DB_HOST:-$VAR_DEF_DB_HOST}"
        --db_port="${UNA_DB_PORT:-$VAR_DEF_DB_PORT}"
        --db_name="$UNA_DB_NAME"
        --db_user="${UNA_DB_USER:-$VAR_DEF_DB_USER}"
        --db_password="${UNA_DB_PWD:-$VAR_DEF_DB_PWD}"
        --server_http_host="${UNA_HTTP_HOST:-$VAR_DEF_HTTP_HOST}"
        --server_php_self="/install/index.php"
        --server_doc_root="/var/www/html/"
        --site_title="${UNA_SITE_TITLE:-$VAR_DEF_TITLE}"
        --site_email="${UNA_SITE_EMAIL:-$VAR_DEF_EMAIL}"
        --admin_username="${UNA_ADMIN_USERNAME:-$VAR_DEF_USERNAME}"
        --admin_email="${UNA_ADMIN_EMAIL:-$VAR_DEF_EMAIL}"
        --admin_password="${UNA_ADMIN_PWD:-$VAR_DEF_ADMIN_PWD}"
        --oauth_key="${UNA_KEY:-}"
        --oauth_secret="${UNA_SECRET:-}"
    )

    if command -v runuser >/dev/null; then
        runuser -u "$UNA_USER" -- "${INSTALL_CMD[@]}"
    else
        su "$UNA_USER" -c "$(printf '%q ' "${INSTALL_CMD[@]}")"
    fi

    rm -rf ./install
fi

# Crontab

if [[ ! -v UNA_NO_CRONTAB ]]; then
    echo "* * * * * /usr/local/bin/php -c /var/www /var/www/html/periodic/cron.php 2>&1 | sed -e \"s/\(.*\)/[\`date\`] \1/\" >>/var/www/cron.log" > /var/www/crontab
    chown $UNA_USER:$UNA_USER /var/www/crontab
    crontab -u $UNA_USER /var/www/crontab

    /etc/init.d/cron start
fi

# subdir config

if [ -n "$UNA_HTTP_PATH" ]; then
    echo "Creating Alias for $UNA_HTTP_PATH"

    cat > "/etc/apache2/conf-available/99-subfolder.conf" <<EOF
Alias /${UNA_HTTP_PATH} /var/www/html/

<Directory /var/www/html/>
    Require all granted
    AllowOverride All
    Options FollowSymLinks
</Directory>
EOF

    a2enconf 99-subfolder
fi

# Disable maintenance page

kill $PID_PHP
wait $PID_PHP || true

#

exec "$@"
