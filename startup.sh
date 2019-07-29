#!/bin/bash
set -e

# Change permissions, host mounted volume adds directory as root.
sudo sh -c "chmod g+s /var/www/html/ && chown craft:www-data /var/www/html/"

# Check if host has bind mounted to '/home/craft/.composer'. 
# Avoid permissions issues by giving write access for all. 
if [ -f /home/craft/.composer/ ]; then 
    sudo chmod -f 777 /home/craft/.composer/
fi

# Use vendor directory as indication of whether project has been fully installed.
if [ -d /var/www/html/vendor/ ]; then
    echo '- Craft project already created.'
else
    echo '- Checking for existing project...'

    setup_mysql_database () {
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE}"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "GRANT ALL PRIVILEGES ON *.* TO ${MYSQL_USER}@'%'"
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} -h${MYSQL_HOSTNAME:-mysql} -e "FLUSH PRIVILEGES"
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
        --site-name=${COMPOSE_PROJECT_NAME} \
        --site-url="https://${SITE_URL}"
    }

# Check if there are any files in /var/www/html.
    if [ ! "$(ls -A /var/www/html/)" ]; then
        echo '- No project found. Creating new instance of CraftCMS...'

# Run Composer as user 'craft' to avoid 'do not run as super-user' warning. 
        composer create-project craftcms/craft /var/www/html/

        ./craft setup/security-key

        setup_mysql_database
        
        setup_craft_database
        
        install_craft

    else 
        echo '- Existing Craft project found! Installing...'

        composer update

        setup_mysql_database

        install_craft

# Manually add site URL to .env file.
        echo -e "\nDEFAULT_SITE_URL=\"https://$SITE_URL\"" >> /var/www/html/.env
   fi
   echo '- Setting write permissions for PHP...'

   sudo chmod -R g+w config vendor web/cpresources storage .env composer.json composer.lock

# Give group access to www-data for all files.
   sudo chown -R craft:www-data /var/www/html/
fi

sudo sh -c "echo 'ServerName ${SITE_URL}' >> /etc/apache2/apache2.conf"

PURPLE='\033[1;35m'
PARTY_POPPER='🎉'

echo -e "\n- Congratulations ${PARTY_POPPER}  your CraftCMS site ready to go! Please visit: ${PURPLE} https://${SITE_URL}\n"

sudo apache2-foreground
