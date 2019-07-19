FROM amd64/php:7.3.0RC6-apache-stretch
RUN apt-get update && apt-get -y upgrade

# INSTALL CERTBOT
RUN echo "deb http://deb.debian.org/debian stretch-backports main" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install certbot python-certbot-apache -t stretch-backports -y

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

# ENABLE APACHE REWRITES
RUN a2enmod ssl && a2enmod rewrite

# INSTALL COMPOSER
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php
RUN php composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN rm composer-setup.php

# COPY SSL CONFIG
COPY config/localdomain.csr.cnf /etc/apache2/
COPY config/localdomain.v3.ext /etc/apache2/

# SET WORKING DIRECTORY
WORKDIR /var/www/html/

# COPY STARTUP SCRIPT
COPY ./config/startup.sh /usr/local/bin/startup

# RUN STARTUP SCRIPT
CMD ["startup"]

# EXPOSE PORTS
EXPOSE 80 443