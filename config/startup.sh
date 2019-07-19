#! /bin/bash
set -e
sed -ri "s/^www-data:x:33:33:/www-data:x:${LOCAL_UID:-1000}:${LOCAL_UID:-1000}:/" /etc/passwd
sed -ri "s/^www-data:x:33:/www-data:x:${LOCAL_UID:-1000}:/" /etc/group
chown -R www-data:www-data /var/www/html

echo "ServerName ${SITE_NAME}" >> /etc/apache2/apache2.conf
if [ ! -f /etc/apache2/sites-available/000-default.conf ]; then
	echo "No virtualhost found!"
	exit 1
else
	export SERVER_ALIAS=`cat /tmp/000-default.conf | grep -o -m 1 'ServerAlias.*' | awk -F "ServerAlias " '/ServerAlias/{print $2}' | sed -e "s/ /,/g"`
	echo $SERVER_ALIAS
	export APACHE_DOCUMENT_ROOT="${APACHE_DOCUMENT_ROOT:-/var/www/html/web}"
	mkdir -p /etc/apache2/conf/extra/
	printf "LoadModule socache_shmcb_module modules/mod_socache_shmcb.so\nLoadModule ssl_module modules/mod_ssl.so\n" > /etc/apache2/conf/extra/httpd-ssl.conf
	sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf 
	rm /etc/apache2/sites-available/default-ssl.conf
	cp /tmp/000-default.conf /etc/apache2/sites-available/000-default.conf
	cd /etc/apache2/sites-available/ && a2ensite * > /dev/null 2>&1
fi

if [ "$(ls -A /var/www/html/$DIR)" ]; then
    echo '- Craft project already created. '
else
    sudo -H -u www-data bash -c 'composer create-project craftcms/craft .'
    chmod -R g+w config web storage vendor .env composer.json composer.lock
fi

export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-256M}"
echo 'memory_limit = ${PHP_MEMORY_LIMIT}' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini;

if [ ${CONFIGURATION} == "development" ]; then
	sed -e 's/max_execution_time = 30/max_execution_time = 120/' -i "${PHP_INI_DIR}/php.ini-${CONFIGURATION}"
fi

if [ ${CONFIGURATION} == "development" ]; then
	if [ ! -f "{PHP_INI_DIR}/php.ini" ]; then
		mv "${PHP_INI_DIR}/php.ini-development" "${PHP_INI_DIR}/php.ini"
	fi

	echo "- Configured for development. Checking for SSL Certificate..."

	export SSL_CERTIFICATE_NAME="${SSL_CERTIFICATE_NAME:-Testing}"
	if [ -d /var/www/html/ssl ]; then
	    echo "- SSL already generated"
	    cp /var/www/html/ssl/localdomain.crt /var/www/html/ssl/localdomain.insecure.key /etc/apache2/
	else
		openssl genrsa -des3 -passout pass:password -out /etc/apache2/localdomain.secure.key 2048  && \
		echo "password" |openssl rsa -in /etc/apache2/localdomain.secure.key -out /etc/apache2/localdomain.insecure.key -passin stdin  && \
		openssl req -new -sha256 -nodes -out /etc/apache2/localdomain.csr -key /etc/apache2/localdomain.insecure.key -config /etc/apache2/localdomain.csr.cnf && \
		openssl genrsa -des3 -passout pass:password -out /etc/apache2/rootca.secure.key 2048  && \
		echo "password" | openssl rsa -in /etc/apache2/rootca.secure.key -out /etc/apache2/rootca.insecure.key -passin stdin  && \
		openssl req -new -x509 -nodes -key /etc/apache2/rootca.insecure.key -sha256 -out /etc/apache2/cacert.pem -days 3650 -subj "/C=GB/ST=London/L=London/O=${SITE_NAME}/OU=IT Department/CN=${SSL_CERTIFICATE_NAME}"  && \
		openssl x509 -req -in /etc/apache2/localdomain.csr -CA /etc/apache2/cacert.pem -CAkey /etc/apache2/rootca.insecure.key -CAcreateserial -out /etc/apache2/localdomain.crt -days 500 -sha256 -extfile /etc/apache2/localdomain.v3.ext
		mkdir /var/www/html/ssl
		chown www-data:www-data -R /var/www/html/ssl
		mv /etc/apache2/cacert.pem /var/www/html/ssl
		cp /etc/apache2/localdomain.crt /etc/apache2/localdomain.insecure.key /var/www/html/ssl
		chown www-data:www-data -R /var/www/html/ssl
	fi

elif [ ${CONFIGURATION} == "production" ]; then
	if [ ! -f "{PHP_INI_DIR}/php.ini" ]; then
		mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"
	fi
	echo "- Configured for production."
	certbot --apache --non-interactive -d "${SITE_NAME}" -d "${SERVER_ALIAS}" --email ${EMAIL}  --agree-tos --no-eff-email --reinstall --redirect
else 
	echo "Configuration type not recognised! Choose 'production' or 'development'."
fi

apache2-foreground
