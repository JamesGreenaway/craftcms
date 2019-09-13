#!/bin/bash
set -e

# Change permissions, host mounted volume adds directory as root.
sudo sh -c "chmod g+s /var/www/html/ && chown craft:craft /var/www/html/"

# Use vendor directory as indication of whether an existing project has been fully installed.
if [ -d /var/www/html/vendor/ ]; then
    echo '- Craft project already created.'
else
    echo '- Checking for existing project...'
    mysql_connect_retry () {
        mysqladmin ping -u${MYSQL_USER} -h${MYSQL_HOST:-mysql} -p${MYSQL_PASSWORD} --silent --wait
    }

    setup_mysql_database () {
        mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE}"
    }

    setup_craft_database () {
        ./craft setup/db-creds --interactive=0 \
        --server=${MYSQL_HOSTNAME:-mysql} \
        --database=${MYSQL_DATABASE} \
        --user=${MYSQL_USER} \
        --password=${MYSQL_PASSWORD} \
        --port=${MYSQL_PORT:-3306} \
        --driver=mysql \
        --table-prefix=${DATABASE_TABLE_PREFIX}
    }
    
    install_craft () {
        ./craft install --interactive=0 \
        --email=${EMAIL_ADDRESS} \
        --username=${USER_NAME} \
        --password=${PASSWORD} \
        --site-name=${SITE_NAME} \
        --site-url=${SITE_URL} \
        --language=${LANGUAGE}
    }

    # Check if there are any files in /var/www/html.
    if [ ! "$(ls -A /var/www/html/)" ]; then
        echo '- No project found. Creating new instance of CraftCMS...'
        # Run Composer as user 'craft' to avoid 'do not run as super-user' warning. 
        composer create-project craftcms/craft /var/www/html/
        ./craft setup/security-key
        mysql_connect_retry
        setup_mysql_database
        setup_craft_database
        install_craft
    else 
        echo '- Existing Craft project found! Installing...'
        composer install
        mysql_connect_retry
        setup_mysql_database
        setup_craft_database
        # Manually add data to .env file.
        echo -e "\nSECURITY_KEY=\"$SECURITY_KEY\"" >> /var/www/html/.env
        echo -e "\nENVIRONMENT=\"dev\"" >> /var/www/html/.env
        echo -e "\nDEFAULT_SITE_URL=\"$SITE_URL\"" >> /var/www/html/.env
        install_craft
    fi
    echo '- Setting write permissions for PHP files...'
    sudo chmod -R g+w config vendor web/cpresources storage .env composer.json composer.lock

fi

# Remove https from SITE_URL.
export SERVER_NAME=`echo $SITE_URL |  awk -F"/" '{print $3}'` 
sudo sh -c "echo 'ServerName ${SERVER_NAME}' >> /etc/apache2/apache2.conf"
# Update Virtual Hosts with server name/alias.
sudo sed -ri "s!Listen 80!Listen 5000!" /etc/apache2/ports.conf
sudo sed -ri "s!ServerName!ServerName ${SERVER_NAME}!" /etc/apache2/sites-available/000-default.conf

exec "$@"