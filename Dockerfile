# Container OS should have PHP and Apache already
FROM php:7.4-apache

MAINTAINER at@una.io

# PHP extensions and necessary packages
RUN apt-get update && apt-get install -y \
        cron \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libonig-dev \
        libmagickwand-dev \
        libzzip-dev \
        sendmail sendmail-bin \
        unzip \
 && docker-php-ext-install -j$(nproc) exif \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j$(nproc) gd \
 && docker-php-ext-install -j$(nproc) iconv \
 && docker-php-ext-install -j$(nproc) mbstring \
 && docker-php-ext-install -j$(nproc) opcache \
 && docker-php-ext-install -j$(nproc) pdo \
 && docker-php-ext-install -j$(nproc) pdo_mysql \
 && docker-php-ext-install -j$(nproc) zip \
 && pecl install mcrypt-1.0.3 \
 && docker-php-ext-enable mcrypt \
 && pecl install imagick-3.4.4 \
 && docker-php-ext-enable imagick \
 && rm -rf /var/lib/apt/lists/*

# User & folder 

RUN groupadd -r --gid 2483 www-una \
 && useradd -r --uid 2483 -g www-una www-una \
 && chown www-una:www-una /var/www/html /var/www

# Unzip package

USER www-una

WORKDIR /var/www/html

ENV UNA_VERSION 11.0.2

# Alternative download URL - https://github.com/unaio/una/releases/download/${UNA_VERSION}/UNA-v.${UNA_VERSION}.zip
RUN curl -fSL "http://ci.una.io/builds/UNA-v.${UNA_VERSION}.zip" -o una.zip \
 && unzip -o una.zip \
 && rm una.zip \
 && mv UNA-v.${UNA_VERSION}/* . \
 && mv UNA-v.${UNA_VERSION}/.htaccess . \
 && rm -rf "UNA-v.${UNA_VERSION}" 

RUN chmod 777 inc cache cache_public logs tmp storage \
 && chmod +x plugins/ffmpeg/ffmpeg.exe

# Apache configuration

USER root

RUN echo "memory_limit=192M \n\
post_max_size=100M \n\
upload_max_filesize=100M \n\
error_log=/var/www/php_error.log \n\
error_reporting=E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT \n\
display_errors=Off \n\
log_errors=On \n\
sendmail_path=/usr/sbin/sendmail -t -i \n\
date.timezone=UTC" > /var/www/php.ini && chown www-una:www-una /var/www/php.ini

RUN touch /var/www/php_error.log \
 && chown www-una:www-una /var/www/php_error.log \
 && chmod 666 /var/www/php_error.log

RUN echo "<VirtualHost *:80> \n\
        DocumentRoot /var/www/html \n\
        PHPINIDir /var/www \n\
        ErrorLog /var/www/error.log \n\
        CustomLog /var/www/access.log combined \n\
</VirtualHost>" > /etc/apache2/sites-enabled/una.conf

RUN a2enmod rewrite expires

# Crontab

RUN echo "* * * * * php -c /var/www /var/www/html/periodic/cron.php" > /var/www/crontab \
 && chown www-una:www-una /var/www/crontab \
 && crontab -u www-una /var/www/crontab 

# Expose port

VOLUME /var/www

EXPOSE 80
