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
#               ***PRODUCTION CONFIGURATION***
# STRONGLY RECOMMENDED: disable logs and assertion compilation 
#RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
#               ******************************

# CHANGE DOCUMENT ROOT
ENV APACHE_DOCUMENT_ROOT /var/www/html
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# ENABLE APACHE REWRITES
RUN a2enmod ssl && a2enmod rewrite

# OVERRIDE VIRTUALHOSTS
COPY apache/httpd-ssl.conf /etc/apache2/conf/extra/httpd-ssl.conf
COPY apache/000-default.conf /etc/apache2/sites-available
COPY apache/default-ssl.conf /etc/apache2/sites-available
RUN a2ensite 000-default.conf && a2ensite default-ssl.conf

# SET SSL KEY
COPY ssl/localdomain.crt /etc/apache2/
COPY ssl/localdomain.insecure.key /etc/apache2/

# SET SERVERNAME TO LOCALHOST
RUN echo "ServerName penguin.linux.test" >> /etc/apache2/apache2.conf

# SET AND PREPARE NEW USER 
RUN useradd -m -s $(which bash) -G sudo,www-data -u 1000 craft
RUN usermod -g www-data craft

# INSTALL COMPOSER
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php
RUN php composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN rm composer-setup.php

# SET WORKING DIRECTORY
WORKDIR /var/www/html/

# EXPOSE PORTS
EXPOSE 80 443

