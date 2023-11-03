# Container OS should have PHP and Apache already
FROM php:8.2-apache

MAINTAINER at@una.io

USER root

# PHP extensions and necessary packages

RUN apt-get update && apt-get install -y \
        cron \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libwebp-dev \
        libonig-dev \
        libmagickwand-dev \
        libzip-dev \
        sendmail sendmail-bin \
        unzip \
 && docker-php-ext-install -j$(nproc) exif \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j$(nproc) gd \
 && docker-php-ext-install -j$(nproc) iconv \
 && docker-php-ext-install -j$(nproc) mbstring \
 && docker-php-ext-install -j$(nproc) opcache \
 && docker-php-ext-install -j$(nproc) pdo \
 && docker-php-ext-install -j$(nproc) pdo_mysql \
 && docker-php-ext-install -j$(nproc) zip \
 && pecl install mcrypt-1.0.6 \
 && docker-php-ext-enable mcrypt \
 && pecl install imagick \
 && docker-php-ext-enable imagick \
 && rm -rf /var/lib/apt/lists/*

# User & folder 

RUN groupadd -r --gid 2483 www-una \
 && useradd -r --uid 2483 -g www-una www-una \
 && chown www-una:www-una /var/www/html /var/www

# Apache configuration

ENV APACHE_RUN_USER www-una
ENV APACHE_RUN_GROUP www-una

RUN echo "memory_limit=192M \n\
post_max_size=100M \n\
upload_max_filesize=100M \n\
error_log=/var/log/php/error.log \n\
error_reporting=E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT \n\
display_errors=Off \n\
log_errors=On \n\
sendmail_path=/usr/sbin/sendmail -t -i \n\
date.timezone=UTC" > /var/www/php.ini && chown www-una:www-una /var/www/php.ini

RUN mkdir /var/log/php && chown www-una:www-una /var/log/php && chmod 777 /var/log/php && su www-una -c "ln -s /dev/stderr /var/log/php/error.log"

RUN echo "<VirtualHost *:80> \n\
        DocumentRoot /var/www/html \n\
        PHPINIDir /var/www \n\
        ErrorLog /var/www/error.log \n\
        CustomLog /var/www/access.log combined \n\
</VirtualHost>" > /etc/apache2/sites-enabled/una.conf

RUN a2enmod rewrite expires

# Expose port and set volume

WORKDIR /var/www/html

VOLUME /var/www

EXPOSE 80

# Entrypoint

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apache2-foreground"]
