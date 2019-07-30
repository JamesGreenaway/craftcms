# A local development environment for CraftCMS with support for HTTPS. 
In an effort to refine the workflow for installing multiple instances of websites running CraftCMS, this project harnesses the power of Docker to isolate the necessary resources to run Craft, and all its prerequisites, in an efficient manner.  This project intends to be as flexible as possible by ensuring that, for every step in the installation process, the user can customise it to suit their preferences. 

This project uses Traefik, an open-source reverse proxy/load balancer, to route each website to its respective container using TLS.  In combination with Mkcert, a simple, zero-config tool used to make locally trusted development certificates with any names you'd like, you can give each website a secure, https-enabled URL that can all run at the same time, on the same port. To begin, there are a few necessary steps that you will need to follow to get up and running.

## Prerequisites
Please install these tools on your computer before continuing:
1. [Docker](https://docs.docker.com/install/)
1. [Docker Compose](https://docs.docker.com/compose/install/)
1. [Homebrew](https://brew.sh/)
1. [Dnsmasq](https://wiki.debian.org/HowTo/dnsmasq)
1. [Mkcert](https://github.com/FiloSottile/mkcert)

Docker is used to run each Craft project in a container.  This means that no matter what device you are running it on each project will be running in the same isolated environment.  Containers can be spun up and down quickly and have rock-solid stability. The images that are used in this project are all based on official images supported by Docker and are all regularly maintained by their respective providers. 
 
Docker Compose is an official tool created by Docker to house all the commands that you need to provide to each container.  We will be using Docker Compose to outline all the instructions that need to be sent to Docker to install and run our Craft projects. 

Homebrew is an optional macOS-specific package manager used to install Dnsmasq and Mkcert. Both tools can be installed without Homebrew, however, for ease-of-use, it is recommended that you install it. *Note*: This will not be required for Linux based devices.

Dnsmasq will help us to map custom domain names to each Craft instance. It will require the user to follow a one-time set-up process to get it running on their machine. 

Finally, as previously explained, Mkcert is the tool that we will use to fabricate our self-signed SSL certificates. Support is given for wildcard domain names and, once installed, requires no configuration. 

## Installation Instructions

### Step 1:
Create a directory called `traefik/` inside the directory create a file `docker-compose.yml`. Copy the following text in to that file:
```
version: "3.7"
services:
  traefik:
    restart: always
    image: traefik:v2.0.0-beta1
    ports:
      - 80:80
      - 443:443
      - 8080:8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./dynamic_conf.toml:/config/dynamic_conf.toml:ro
      - ./certs:/certs:ro
    command: 
      --entrypoints.web.address=:80
      --entrypoints.web-secure.address=:443
      --entrypoints.traefik.address=:8080
      --providers.docker=true
      --providers.file.filename=/config/dynamic_conf.toml
      --providers.file.watch=true      
      --log.level=DEBUG
      --log=true
      --api=true
    networks:
      - traefik
  mysql:
    image: mysql:5.7
    restart: always
    volumes:
      - mysql:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_USER: user
      MYSQL_PASSWORD: password
    depends_on:
      - traefik
    networks:
      - traefik
volumes: 
  mysql: {}
networks:
  traefik:
    external: true
```
Here we are creating two services: `traefik` and `mysql`.  The first service, `traefik` , is what acts as the gatekeeper to all of our other services (or containers). Traefik is currently undergoing some major changes and version 2.0 is still in beta. Despite this, we are using the beta version and will be keeping an eye on all ongoing future changes. Here we will open up all the ports we want to expose to our other containers.  Ports 80 and 443 are used to route data to other containers 8080 will show Traefiks (currently being updated) UI which can be found by going to `localhost:8080`.  Traefik will see all of our containers by listening to the docker socket, this will dynamically update according to what containers we start and stop. Traefik will route the data using an external network called traefik that links all our containers together. 

We also have a `certs` directory which will link all our certificates to Traefik.  For Traefik to see these certificates, however, we will need to reference them in a file called `dynamic_conf.toml`. Please make this file and see the section on Mkcert below for an example of the format of this file.

The second service we create is called `mysql`, here we are using MySQL's official docker image.  We are creating a named volume also called `mysql` which will store our persistent database data locally on our machine, allowing us to start and stop our container without fear of losing all our data. We are also using three environment variables that are required to create a root and custom user with their respective passwords. 

#### How To Run
To run this file we will first need to create our external network by entering: `docker network create traefik`. Now we can run our docker-compose file by entering `docker-compose up -d` inside the `traefik/` directory.  Our services, `traefik` and `mysql` will now be initialized and running.  To stop them running you can enter `docker-compose down` however, for the most part, these can just be left up and running all the time. You can see all running containers by entering `docker ps -a`. 

### Step 2: 
Next we need a place to run our website. Create another separate directory with the name of our website. Inside that directory copy the following text in to another `docker-compose.yml` file: 
``` 
version: "3.7"
services:
  craft:
    image: jamesgreenaway/craftcms:latest
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./craft:/var/www/html/
      - ./virtualhost.conf:/etc/apache2/sites-available/000-default.conf
      - type: bind
        source: /path/to/local/.composer/
        target: /home/craft/.composer/
    labels:
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.entrypoints=web
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.entrypoints=web-secure
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.middlewares=https
      - traefik.http.middlewares.https.redirectscheme.scheme=https
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.tls=true
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.rule=Host(
        `${COMPOSE_PROJECT_NAME}.test`, `www.${COMPOSE_PROJECT_NAME}.test`)
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.rule=Host(
        `${COMPOSE_PROJECT_NAME}.test`, `www.${COMPOSE_PROJECT_NAME}.test`)
    networks: 
      - traefik
networks:
  traefik:
    external: true
```
This file uses a custom image that is based on the official PHP apache and Composer images.  We are using PHP version 7.3 and the latest version of Composer. When built, this image will install all of the necessary packages and settings that are required to run CraftCMS. When run, the image will determine whether you need a fresh installation of Craft to be installed or whether you are using an existing project. If you are starting a new project, a volume called `craft/` will be automatically created and a new instance of Craft will be installed inside it. To migrate an existing project, you must create a directory called `craft/` and install your project inside it. Please see below for further information on how to migrate an existing project. Optionally, the above file uses a bind-mounted volume to connect to our local `.compose` file. This is a recommended addition, as it allows you to cache each version of Craft and significantly reduces the time it takes to download and install. 

To run this image you will first need to provide it with a couple of additional files. There needs to be a file named `.env`, this will be used to list all of our environment variables that we will need to customise our installation. We must also include a `virtualhost.conf` file to customise the Apache server to our requirements. Please see below for a listing of all the environment variables that we can use and an example of how you may wish to set-up your Virtual Host. 

We are communicating with Traefik via labels. Labels outline all the dynamic configuration commands we need to update Traefik with. Traefik will update automatically whenever we add a new project. Here we link the `craft` service to our ports, tell Traefik that we would like to connect using TLS protocol and also provide it with the domain names we intend to use. Our domain names have been configured to use the environment variable named `$COMPOSE_PROJECT_NAME` (see below for further information) and can also include optional subdomains i.e. `www.` or `dev.`, they just need to be added to both the labels with the Host rule in the form of a comma-separated and backtick-surrounded list. We are also providing Traefik with optional middleware which will redirect all HTTP connections to HTTPS. 

#### How To Run
* `docker-compose up -d` - to run 
> *Note*: This can take some time, please see the `logs` command below to follow the installation progress.
* `docker-compose down` - to stop

##### Other Useful Commands
* `docker-compose logs -f` - to watch the logs
* `docker-compose exec projectname_craft_1 /bin/bash` - to start and interactive TTY session inside the container

## Environment Variables
* `MYSQL_ROOT_PASSWORD=password`
> Needed so that the Craft instance can create database entries. *Note*: Must match the environment variables used in our mysql service.
* `MYSQL_USER=user`
> Needed so that the Craft instance can create database entries. *Note*: Must match the environment variables used in our mysql service.
* `MYSQL_PASSWORD=password`
> Needed so that the Craft instance can create database entries. *Note*: Must match the environment variables used in our mysql service.
* `MYSQL_DATABASE=db`
> Creates a database using this name. Grants all privileges to `$MYSQL_USER`.
* `DATABASE_TABLE_PREFIX=craft`
> *Optional*: Sets the table prefix for the Craft database.  
* `EMAIL_ADDRESS=test@test.com`
> Sets the email address for Craft dashboard.
* `USER_NAME=admin`
> Sets the username for Craft dashboard.
* `PASSWORD=password`
> Sets the password for Craft dashboard.
* `SITE_URL=example.test`
> Sets the website name inside Craft and is also used to set the `ServerName` for Apache. *Important*: Please omit the `https://` protocol.
* `COMPOSE_PROJECT_NAME=example`
> *Important*: This variable serves to set the name of the whole project. It is also used to set the name of the certificate file, therefore, it is important to ensure that it matches the same name given to the certificates for this site (see below) and the main ServerName and ServerAlias on your `virtualhost.conf` file. Finally, it is also used in the `docker-compose.yml` file to set the name of the routers and Host rules for Traefik, however, this is done simply as a convenience measure. 

Here is an example file for your reference: 
```    
MYSQL_ROOT_PASSWORD=password
MYSQL_USER=user
MYSQL_PASSWORD=password
MYSQL_DATABASE=uniqueDatabaseName
EMAIL_ADDRESS=test@test.com
USER_NAME=admin
PASSWORD=password
SITE_URL=example.test
COMPOSE_PROJECT_NAME=example
```

## Additional Features

## Existing project migrations
For project migrations, you will need to add a `.env` file inside the `craft/` directory and ensure that the following environment variables are set to integrate it correctly: 

* ENVIRONMENT 
* SECURITY_KEY *Must match the existing project*

The following environment variables will be automatically populated by using our project's `.env` file:

* DB_DRIVER 
* DB_SERVER 
* DB_USER 
* DB_PASSWORD 
* DB_DATABASE
* DEFAULT_SITE_URL

Our docker image will then run `composer update` to install all the dependencies and either link it to an existing database or create a new one for you depending on whether a database under the value given to `$MYSQL_DATABASE` already exists.  

### Setting up your Virtual Host. 
To add your Virtual Host you must create a file called `virtualhost.conf` inside the project's directory.  Here is one example of how you may wish to layout your `virtualhost.conf` file: 

```
<VirtualHost *:80>
    DocumentRoot /var/www/html/web
    ErrorLog ${APACHE_LOG_DIR}/errors.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    ServerAlias www.example.test
    ServerName example.test
    <Directory /var/www/html/web>
      Options Indexes FollowSymLinks
      AllowOverride All
      Require all granted
    </Directory>
</VirtualHost>
```

### Building the image with alternative arguments. 
It is also possible to build this image with some additional arguments. This can alter some of the lower level settings that are already predetermined. To add these arguments, you need to reference the Github repository as a context and add the arguments to the `docker-compose.yml`. For example: 
```
services:
  craft:
    image: jamesgreenaway/craftcms
    build:
      context: https://github.com/JamesGreenaway/craftcms.git
      args:
        ENVIRONMENT_VARIABLE: value 
... 
```
These are the environment variables that are available to add (if necessary): 
* LOCAL_UID
> This is useful to modify if you are using a Linux device to run this image and your UID is not 1000. Editing this argument will edit the user inside your container to match the UID of your local machine. 
* PHP_MEMORY_LIMIT
> The recommended memory limit for Craft is 256M this is already set as a default. Use this variable if you require more memory.  
* MAX_EXECUTION_TIME
> The recommended execution time for Craft is 120 this is already set as a default. Use this variable if you require more time. 
* ENVIRONMENT
> This image has been created to be environment agnostic, the current default is `development` however, if you need to run this in a production environment you can use `production`. This will set the php.ini so that it is ready for production. 

#### How To Build

* `docker-compose build` 

### Exporting and importing databases.
* `docker exec <container-name> sh -c 'exec mysqldump <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' > mysqldump.sql`
> This will take an existing database and dump the contents of the database in a file named mysqldump.sql

* `docker exec -i <container-name> sh -c 'exec mysql <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' < mysqldump.sql`
> This will take an existing mysqldump.sql and dump its contents in to a database of your choosing.

* `docker exec <container-name> sh -c 'exec mysqldump <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' | ssh <remote_server> mysql -uroot <database>`
> This will take an existing database and dump the contents of the database in to a named database inside a remote server

* `ssh <remote_server> mysqldump <database> | docker exec -i <container-name> sh -c 'exec mysql <database> -uroot -p"$MYSQL_ROOT_PASSWORD"'`
> This will take a existing database inside a remote server and dump the contents inside named local database. 

## Configuring the Other Tools

### Dnsmaq

#### MacOS

*Create a DNS resolver*

`sudo mkdir -p /etc/resolver`

`echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolver/test > /dev/null`

*Configure Dnsmasq for .test domains*

`echo 'address=/.test/127.0.0.1' >> $(brew — prefix)/etc/dnsmasq.conf`

*Start Dnsmasq as a service so it automatically starts at login (macOS only)*

`sudo brew services start dnsmasq`

#### Linux
Linux does not offer the option to add resolvers to `/etc/resolver`. You must uncomment `prepend domain-name-servers 127.0.0.1;` from `/etc/dhcp/dhclient.conf` to ensure that the dhclient overrides `resolv.conf` with our localhost's IP address. In some cases (ChromeOS' Project Crostini) you may also need to feed the `dhclient.conf` file with Google's public DNS servers like so: `prepend domain-name-servers 127.0.0.1,8.8.8.8,8.8.4.4;`. You will also need to restart your local machine to run the dhclient script which will override the `resolv.conf` file. 

### Mkcert
Please consult [mkcert](https://github.com/FiloSottile/mkcert) for full installation instructions. *Note*: Once you have installed Mkcert you will likely need to restart your local machine. 

To create a certificate for each project ensure that you are inside the `traefik/` directory and run the following command replacing `example` with the value used for `$COMPOSER_PROJECT_NAME`:

`mkcert -cert-file certs/example-cert.pem -key-file certs/example-key.pem "example.test" "*.example.test"`

It is possible to add more domain names if required. For example, if you are adding a subdomain you would add `"dev.example.test"`. 

Once you have created your certificates you will need to inform Traefik where it can locate them. Please add a file inside the `traefik/` directory called `dynamic_conf.toml` and include the following text for each project you create certificates for:

```
[tls]
  [[tls.certificates]]
    certFile = "/certs/example-cert.pem"
    keyFile = "/certs/example-key.pem"
```

*Note*: hopefully this step will not be necessary in the future when Traefik v2.0 is out of beta.

Finally, you will need to restart Traefik by entering: 
`docker-compose restart traefik`
