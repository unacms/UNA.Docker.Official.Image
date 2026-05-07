# ---- Builder ----

FROM php:8.3-apache AS builder

MAINTAINER at@una.io

USER root

# PHP extensions and necessary packages

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libonig-dev \
        libmagickwand-dev \
        libzip-dev \
 && docker-php-ext-install -j$(nproc) exif \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j$(nproc) gd \
 && docker-php-ext-install -j$(nproc) iconv \
 && docker-php-ext-install -j$(nproc) mbstring \
 && docker-php-ext-install -j$(nproc) opcache \
 && docker-php-ext-install -j$(nproc) pdo \
 && docker-php-ext-install -j$(nproc) pdo_mysql \
 && docker-php-ext-install -j$(nproc) zip \
 && pecl install imagick \
 && docker-php-ext-enable imagick \
 && rm -rf /var/lib/apt/lists/*

# ---- Runtime ----

FROM php:8.3-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    libfreetype6 \
    libjpeg62-turbo \
    libpng16-16 \
    libwebp7 \
    libonig5 \
    imagemagick \
    libzip5 \
    unzip \
 && rm -rf /var/lib/apt/lists/* /tmp/*

 # Copy compiled extensions

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# ENV vars

ENV UNA_USER="www-una" \
        VAR_DEF_DB_HOST="localhost" \
        VAR_DEF_DB_PORT="3306" \
        VAR_DEF_DB_USER="root" \
        VAR_DEF_DB_PWD="root" \
        VAR_DEF_HTTP_HOST="localhost" \
        VAR_DEF_TITLE="UNA" \
        VAR_DEF_USERNAME="admin" \
        VAR_DEF_ADMIN_PWD="admin" \
        VAR_DEF_EMAIL="admin@example.com" \
        VAR_DEF_DB_ENGINE="MYISAM" \
        VAR_DEF_AUTO_HOSTNAME=0 \
        VAR_DEF_VERSION="14.0.0" \
        APACHE_RUN_USER=$UNA_USER \
        APACHE_RUN_GROUP=$UNA_USER

# User & folder 

RUN groupadd -r --gid 2483 $UNA_USER \
 && useradd -r --uid 2483 -g $UNA_USER $UNA_USER \
 && chown $UNA_USER:$UNA_USER /var/www/html /var/www

# Apache configuration

RUN echo "memory_limit=192M \n\
post_max_size=100M \n\
upload_max_filesize=100M \n\
error_log=/var/log/php/error.log \n\
error_reporting=E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT \n\
display_errors=Off \n\
log_errors=On \n\
date.timezone=UTC" > /usr/local/etc/php/conf.d/una.ini

RUN mkdir /var/log/php && mkdir /var/www/ssl && chown $UNA_USER:$UNA_USER /var/log/php && chmod 777 /var/log/php && su $UNA_USER -c "ln -s /dev/stderr /var/log/php/error.log; ln -s /dev/stderr /var/www/cron.log"

RUN a2enmod rewrite expires ssl

# Expose port and set volume

WORKDIR /var/www/html

COPY header.inc.php /srv/

RUN set -eux; \
    su "$UNA_USER" -c "\
        curl -fSL \"http://ci.una.io/builds/UNA-v.${VAR_DEF_VERSION}.zip\" -o una.zip && \
        unzip -o una.zip && \
        rm una.zip && \
        mv \"UNA-v.${VAR_DEF_VERSION}\"/* . && \
        mv \"UNA-v.${VAR_DEF_VERSION}\"/.htaccess . && \
        rm -rf \"UNA-v.${VAR_DEF_VERSION}\" && \
        chmod 777 inc cache cache_public logs tmp storage && \        
        chmod +x plugins/ffmpeg/ffmpeg.exe && \
        \\cp -f --no-preserve=mode,ownership /srv/header.inc.php install/patterns/ \
    "

VOLUME /var/www

EXPOSE 80

# Entrypoint

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]