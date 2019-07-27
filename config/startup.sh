#!/bin/bash
set -e
sudo groupmod --new-name ${LOCAL_MACHINE_USER} www-data
sudo sh -c "echo \"export APACHE_RUN_USER=${LOCAL_MACHINE_USER}\" >> ~/.bashrc"
sudo sh -c "echo \"export APACHE_RUN_GROUP=${LOCAL_MACHINE_USER}\" >> ~/.bashrc"

if [ -f /tmp/traefik/$COMPOSE_PROJECT_NAME.toml ]; then
    sudo rm /tmp/traefik/$COMPOSE_PROJECT_NAME.toml
fi
echo -e "\n[tls]\n  [[tls.certificates]]\n    certFile = \"/certs/$COMPOSE_PROJECT_NAME-cert.pem\"\n    keyFile = \"/certs/$COMPOSE_PROJECT_NAME-key.pem\"\n" | sudo tee /tmp/traefik/$COMPOSE_PROJECT_NAME.toml > /dev/null

if [ -d /var/www/html/vendor/ ]; then
    echo '- Craft project already created.'
else
    sudo chmod g+s /var/www/html/
    sudo chown -R craft:www-data /var/www/html/
    setup_mysql_database () {
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE}"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "GRANT ALL PRIVILEGES ON *.* TO ${MYSQL_USER}@'%'"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "FLUSH PRIVILEGES"
    }

    echo '- Checking for existing project...'
    if [ ! "$(ls -A /var/www/html/)" ]; then
        echo '- No project found. Creating new instance of CraftCMS...'
        composer create-project craftcms/craft /var/www/html/
        ./craft setup/security-key
        setup_mysql_database
        ./craft setup/db-creds --interactive=0 \
        --server=${MYSQL_HOSTNAME:-mysql} --database=${MYSQL_DATABASE} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --port=${MYSQL_PORT:-3306} --driver=mysql --table-prefix=${DATABASE_TABLE_PREFIX}
        ./craft install --interactive=0 --email=${EMAIL_ADDRESS} --username=${USER_NAME} --password=${PASSWORD} --site-name=${COMPOSE_PROJECT_NAME} --site-url=${DEFAULT_SITE_URL}
        echo "DEFAULT_SITE_URL=\"https://$DEFAULT_SITE_URL\"" >> /var/www/html/.env
    else 
        echo '- Existing Craft project found! Installing...'
        composer update
        ./craft setup/security-key
        setup_mysql_database
        ./craft setup/db-creds --interactive=0 \
        --server=${MYSQL_HOSTNAME:-mysql} --database=${MYSQL_DATABASE} --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} --port=${MYSQL_PORT} --driver=mysql --table-prefix=${DATABASE_TABLE_PREFIX}
   fi
   sudo chmod -R g+w config vendor web/cpresources storage .env composer.json composer.lock 
   sudo chown -R craft:www-data /var/www/html/
fi

if [ -f /tmp/virtualhost.conf ]; then
    sudo cp /tmp/virtualhost.conf /etc/apache2/sites-available/000-default.conf
else
    sudo sed -ri "s!ServerName!ServerName ${DEFAULT_SITE_URL}!" /etc/apache2/sites-available/000-default.conf
fi

sudo sh -c "echo 'ServerName ${DEFAULT_SITE_URL}' >> /etc/apache2/apache2.conf"
sudo apache2-foreground
