FROM amd64/php:7.3.0RC6-apache-stretch
RUN apt-get update && apt-get -y upgrade

# INSTALL INTL, IMAGEMAGIK, ZIP EXTENSIONS, NETWORK TOOLS, ETC...
RUN apt-get install -y \ 
    zlib1g-dev libicu-dev g++ \
    libmagickwand-dev libzip-dev \
    net-tools iputils-ping \
    git unzip \
    sudo \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-install zip \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && docker-php-ext-install pdo pdo_mysql

# SET MEMORY LIMIT 
RUN echo 'memory_limit = 256M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini;
RUN sed -e 's/max_execution_time = 30/max_execution_time = 120/' -i ${PHP_INI_DIR}/php.ini-development
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
#               ***PRODUCTION CONFIGURATION***
#STRONGLY RECOMMENDED: disable logs and assertion compilation 
#RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
#               ******************************

# CHANGE DOCUMENT ROOT
ENV APACHE_DOCUMENT_ROOT /var/www/html
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# ENABLE APACHE REWRITES
RUN a2enmod ssl && a2enmod rewrite

# OVERRIDE VIRTUALHOSTS
COPY config/httpd-ssl.conf /etc/apache2/conf/extra/httpd-ssl.conf
COPY config/000-default.conf /etc/apache2/sites-available
COPY config/default-ssl.conf /etc/apache2/sites-available
RUN a2ensite 000-default.conf && a2ensite default-ssl.conf

# SET SERVERNAME TO LOCALHOST
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# INSTALL COMPOSER
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php
RUN php composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN rm composer-setup.php

# COPY SSL CONFIG
COPY config/localdomain.csr.cnf /etc/apache2/
COPY config/localdomain.v3.ext /etc/apache2/

# COPY STARTUP SCRIPT
COPY ./config/startup /usr/local/bin

# SET WORKING DIRECTORY
WORKDIR /var/www/html/

# RUN STARTUP SCRIPT
CMD ["startup"]

# EXPOSE PORTS
EXPOSE 80 443

