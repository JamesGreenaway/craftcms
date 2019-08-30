FROM composer:1.9.0
FROM php:7.3-apache-stretch
RUN apt-get update && apt-get -y upgrade

# INSTALL INTL, IMAGEMAGIK, ZIP EXTENSIONS, NETWORK TOOLS, ETC...
RUN apt-get install -y \ 
    zlib1g-dev libicu-dev g++ \
    libmagickwand-dev libzip-dev \
    sudo mysql-client unzip iputils-ping\
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-install zip \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && docker-php-ext-install pdo pdo_mysql

# SETUP APACHE
# RUN a2enmod ssl && a2enmod rewrite
RUN a2enmod rewrite
RUN sed -ri "s!/var/www/!/var/www/html/web!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
COPY ./virtualhost.conf /etc/apache2/sites-available/000-default.conf

# CREATE USER
ARG LOCAL_UID=1000
RUN groupadd -g $LOCAL_UID craft && \
    useradd -rm -s /bin/bash -u $LOCAL_UID -g craft -G sudo craft
RUN echo "craft ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/craft && \
    chmod 0440 /etc/sudoers.d/craft
ENV APACHE_RUN_USER craft
ENV APACHE_RUN_GROUP craft

# INSTALL COMPOSER
COPY --from=composer /usr/bin/composer /usr/bin/composer

# SET WORKING DIRECTORY
WORKDIR /var/www/html/

# CONFIGURE PHP
ARG PHP_MEMORY_LIMIT=256M
ARG MAX_EXECUTION_TIME=120
ARG ENVIRONMENT=development
RUN  sh -c "echo 'memory_limit = $PHP_MEMORY_LIMIT' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini" && \
sed -ri "s!max_execution_time = 30!max_execution_time = $MAX_EXECUTION_TIME!" -i "$PHP_INI_DIR/php.ini-$ENVIRONMENT" && \
mv "$PHP_INI_DIR/php.ini-$ENVIRONMENT" "$PHP_INI_DIR/php.ini"

# COPY SCRIPTS
COPY ./startup.sh /usr/local/bin/startup
RUN chmod a+x /usr/local/bin/startup

# CHANGE USER
USER craft

# RUN STARTUP SCRIPT
ENTRYPOINT ["startup"]
CMD ["apache2-foreground"]

# EXPOSE PORTS
EXPOSE 5000