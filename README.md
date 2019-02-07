### Introduction
This docker image extends the official PHP / Apache build to include CraftCMS, MySQL and SSL Certification.
Currently only suitable for local use. Compatible with macOS, Linux and Chromebook (Crostini).

## How to use

#### docker-compose.yml
```yaml
version: '3'
services: 
  mysql:
    image: mysql:5.7
    restart: unless-stopped
    volumes: 
      - mysql:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: db
      MYSQL_USER: user
      MYSQL_PASSWORD: password
  craft:
    image: jamesgreenaway/craftcms:latest
    restart: unless-stopped
    depends_on: 
      - mysql
    environment: 
      LOCAL_UID: 1000
      SSL_SITE_NAME: Craft
    ports: 
      - "5000:443"
      - "8080:80"
    volumes: 
      - ./craft:/var/www/html/
volumes: 
  mysql: {}
```

### Usage
1. Copy "docker-compose.yml" in to website directory and update default environment variables (see below for more information).

1. Run ```$ docker-compose up```.

1. Add self-certified SSL certificate to browsers certificate manager: 
>For macOS users:
* Double-click ```website/craft/ssl/cacert/pem``` to open the certificate in the Keychain Access utility
* Double-click the certificate
* Click the arrow next to Trust
* Change the "When using this certificate" field to "Always Trust" and close the window
* Enter password to confirm
    
>For Chromebook (Crostini) users:
* Go to ```chrome://certificate-manager/```
* Click "Authorities" then "IMPORT"
* Select ```website/craft/ssl/cacert.pem```
* Choose "Trust this certificate for identifying websites"
* Click "OK"
    
1. Go to ```https://localhost:5000/index.php?p=admin/install```

1. Complete craft installation process:
* Accept license agreement
* Driver: MySQL
* Server: mysql
* Port: 3306
* Username: ```MYSQL_USER```
* Password: ```MYSQL_PASSWORD```
* Database Name: ```MYSQL_DATABASE```
* Create your account
* Set up your site

## Setting environment variables

In order to customise Craft to your site you must set the follwing environment variables in your docker-compose file: 

* ```MYSQL_ROOT_PASSWORD```
* ```MYSQL_DATABASE```
* ```MYSQL_USER```
* ```MYSQL_PASSWORD```
* ```LOCAL_UID```\*
* ```SSL_SITE_NAME```\**

\* For Linux users, your ```LOCAL_UID``` must match the UID of the host.  This can be found by typing ```$ id -u```. (This environment variable can be ignored for macOS users.)

\** The ```SSL_SITE_NAME``` environment variable is used to name the SSL certificate.  The certificates for each new site can be found under their respective name and (for Chromebooks) under the heading "org-localhost".  Each site can be freely deleted once finished with. 

## Further information
* It is advised that you start docker-compose with a project name by typing ```docker-compose -p <project-name> up```. This will avoid any future name collisions with other containers

* Your container can be ran in the background by adding the optional ```-d``` flag.  However, please note that Craft will need to install after the image has been built and will it take a few minutes before the installation process has completed.  The progress of this can be seen by typing ```docker logs <project-name>_craft_1 -f```.

* Other ports can be used on your local device if necessary.

## Links

* [Docker Hub](https://hub.docker.com/r/jamesgreenaway/craftcms)
* [Github](https://github.com/JamesGreenaway/craftcms) 
