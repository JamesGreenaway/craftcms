# A fully customisable local development workflow for CraftCMS. 
In an effort to refine the workflow for installing multiple instances of websites running CraftCMS, this project harnesses the power of Docker to isolate the necessary resources to run Craft, and all its prerequisites, in an efficient manner.  This project intends be as flexible as possible by ensuring that, for every step in the installation process, there is the possibility for the user to customise it to suit their preferences. 

This project uses Traefik, a open-source reverse proxy / load balancer, to route each website to its respective container through a tls connection.  Using mkcert, a simple, zero-config tool to make locally trusted development certificates with any names you'd like, you are able to give each website a secure, https-enabled url that can run alongside all your other websites. In order to begin, there are a few necessary steps that you will need to follow to get up and running.

## Prerequisites
Please install these tools on you computer before continuing:
1. [Docker](https://docs.docker.com/install/)
1. [Docker Compose](https://docs.docker.com/compose/install/)
1. [Homebrew](https://brew.sh/)
1. [Dnsmasq](https://wiki.debian.org/HowTo/dnsmasq)
1. [Mkcert](https://github.com/FiloSottile/mkcert)

Docker is used to run each Craft project in a container.  This means that no matter what device you are running it on, as long as it can run Docker, each project will be running in the same isolated environment.  Containers can be spun up and down quickly and have rock-solid stability. The images that are used in this project are all based on official images supported by Docker, and are all regularly maintained by their respective providers. 
 
Docker Compose is official tool created by Docker to house all the commands that you need to to provide to each container.  We will be using Docker Compose to outline all the instructions that need to be sent to Docker to install and run our Craft projects. 

Homebrew is an optional MacOS-specific package manager used to install Dnsmasq and Mkcert. Both tools can be installed without Homebrew, however for ease-of-use it is recommended that you install it. Note: This will not be required for Linux based devices.

Dnsmasq will help us to map our own custom domain names to each website and will require the user to follow a one-time set-up process to get it running on their machine. 

Finally, as previously explained, Mkcert is the tool that we will use to fabricate our self-signed ssl certificates. Support is given for wildcard domain names and, once installed, requires no configuration. 

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
      - traefik:/config:ro
      - ./certs:/certs:ro
    command: 
      --entrypoints.web.address=:80
      --entrypoints.web-secure.address=:443
      --entrypoints.traefik.address=:8080
      --providers.docker=true
      --providers.file.directory=/config
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
  traefik:
    external: true
networks:
  traefik:
    external: true
```
Here we are creating two services: traefik and mysql.  The first service, traefik, is what acts as the gatekeeper to all of our other services (or containers). Traefik is currently undergoing some major changes and version 2.0 is still in beta. Despite this we are using the beta version and will be keeping an eye on all ongoing future changes. Here we will open up all the ports we want to expose to our other containers.  Port 80 and 443 get sent to our websites and 8080 will show Traefiks (currently being updated) UI which can be found by going to `localhost:8080`.  Traefik will see all of our containers by listening to the docker socket, this will dynamically update according to what containers we start and stop. Traefik will route the data using an external network called traefik that links all our containers together. 

Traefik is linked to an external volume also named traefik, this is how we update traefik with instructions of where to find the certificates for each website we create. This is done automatically each time we run a new instance of Craft. We also have a `certs` directory which will link all our certificates to traefik for it to reference.  Finally we are sending it some static configuration commands that outline the ports we wish to create and through what format we intend to dynamically update traefik. 

The second service we create is called mysql, here we are using mysql's official docker image.  We are creating a named volume called mysql which allows us to store our persistent database data locally on our machine, allowing us to start and stop our container without fear of losing all our data. We are also using three environment variables that are required to create a root user and custom user with their respective passwords. This service is also linked to traefik via the external network and volume which mentioned above. 

#### How To Run
In order to run this file we will first need to create our external network and volume by entering: `docker network create traefik` and `docker volume create traefik`. Now we can run our docker-compose file by entering `docker-compose up -d` inside the `traefik/` directory.  Our services, traefik and mysql will now be initialized and running.  To stop them running you can enter `docker-compose down` however for the most part these can just be left up and running all the time. You can see all running containers by entering `docker ps -a`. 

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
      - traefik:/tmp/traefik
      - ./craft:/var/www/html/
      - ./virtualhost.conf:/tmp/virtualhost.conf
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
volumes:
  traefik:
    external: true
```
This file uses a custom image that is based on the official PHP apache and Composer images.  We are using PHP version 7.3 and the latest version of Composer. When built, this image will install all of the necessary packages and settings that are required to run CraftCMS. When run, the image will determine whether you need a fresh installation of Craft to be installed or whether you are using an existing project. If you are starting a new project, a craft volume will be automatically created and a new instance of Craft will be install inside it. In order to migrate an existing project, you must create a directory called `craft/` and install your project inside it. Our docker image will run `composer update` to install all the dependencies and either link it to an existing database or create a new one for you. 

In order to run this image however, you will first need to provide it with a couple of additional files. There needs to be a file named `.env`, this will be used to list all of our environment variables that we will need to customise our installation. Please see below for a listing of all the environment variables that we can use. We can also include an optional `virtualhost.conf` file to customise the Apache server to our requirements. Note: If this is not added a virtualhost using the environment variable (see below) `$DEFAULT_SITE_URL` for its ServerName, will be automatically created. 

We must also inform Traefik of our intentions. The labels provided link this craft service to our open ports, tell Traefik that we would like a tls connection and provide it with the domain names we intend to use. Our domain names have been configured to use the environment variable named `$COMPOSE_PROJECT_NAME` (see below for further information) and can include optional subdomains i.e. `www.` or `dev.`, they just need to be added to both the labels with the Host rule in the form of a comma separated, backtick surrounded list. We are also providing Traefik with optional middleware which will redirect all http connections to https. 

Finally, our craft service is then linked to our external network and volume allowing it to communicate with Traefik and our mysql service we created above. 

#### How To Run
* `docker-compose up -d` - to run
* `docker-compose down` - to stop

##### Other Useful Commands
* `docker-compose logs -f` - to see and follow the logs (useful when installing to follow the Craft installation)
* `docker exec -it projectname_craft_1 /bin/bash` - to start and interactive tty session inside the container

## Environment Variables
* `MYSQL_ROOT_PASSWORD=password`
> Needed so that the Craft instance can create database entries. *Note*: Must match the environment variables used in our mysql service.
* `MYSQL_USER=user`
> Needed so that the Craft instance can create database entries. *Note*: Must match the environment variables used in our mysql service!
* `MYSQL_PASSWORD=password`
> Needed so that the Craft instance can create database entries. *Note*: Must match the environment variables used in our mysql service!
* `MYSQL_DATABASE=db`
> Creates a database using this name. Grants all privileges to `$MYSQL_USER`.
* `MYSQL_PORT=3306`
> *Optional*: Sets the port for mysql, default is already set to 3306.
* `MYSQL_HOST_NAME=mysql`
> *Optional*: Sets the name of the mysql service. Only necessary to change if the service name is different. 
* `DATABASE_TABLE_PREFIX=craft`
> *Optional*: Sets the table prefix for the Craft database.  
* `EMAIL_ADDRESS=test@test.com`
> Sets the email address for Craft dashboard.
* `USER_NAME=admin`
> Sets the username for Craft dashboard.
* `PASSWORD=password`
> Sets the password for Craft dashboard.
* `DEFAULT_SITE_URL=example.test`
> Sets the website name inside Craft and is also used to set the `ServerName` for Apache. Please omit the `https://` protocol.
* `COMPOSE_PROJECT_NAME=example`
> *Important*: This variable serves to set the name of the whole project. This useful for when you need to execute docker commands on this container.  It is also used to set the name of the certificate file therefore it is important to ensure that is matches the same name given to the certificates for this site. Finally it is also used to set the name of the Traefik routers and Host rules.

## Additional Features

### Setting up your own custom virtualhost. 
In order to add your own custom virtualhost you can create a file called `virtualhost.conf` inside the project directory. It is also possible to add a subdomain, in order for your site to be housed within the `craft/` volume ensure that your `DocumentRoot` is within `/var/www/html/...`.

### Building the image with alternative arguments. 
It is also possible to build this image with some additional arguments. This can alter some of the lower level setting that are already predetermined. In order to add these arguments you need to reference the Github repository as a context and add the arguments to the `docker-compose.yml`. For example: 
```
services:
  craft:
    image: jamesgreenaway/craftcms
    build:
      context: https://github.com/JamesGreenaway/craftcms.git
      dockerfile: /Dockerfile
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

* `docker-compose build` - to build

### Exporting and importing databases.
* `docker exec <container-name> sh -c 'exec mysqldump <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' > mysqldump.sql`
> This will take an existing database and dump the contents of the database in a file named mysqldump.sql

* `docker exec -i <container-name> sh -c 'exec mysql <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' < mysqldump.sql`
> This will take an existing mysqldump.sql and dump its contents in to a database of your choosing.

* `docker exec <container-name> sh -c 'exec mysqldump <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' | ssh <remote_server> mysql -u root <database>`
> This will take an existing database and dump the contents of the database in to a named database inside a remote server

* `ssh <remote_server> mysqldump <database> | docker exec -i <container-name> sh -c 'exec mysql <database> -u root -p "$MYSQL_ROOT_PASSWORD"'`
> This will take a existing database inside a remote server and dump the contents inside named local database. 

## Configuring the Other Tools

### Dnsmaq

#### MacOS

*Create a dns resolver*

`sudo mkdir -p /etc/resolver`

`echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolver/test > /dev/null`

*Configure Dnsmasq for test*

`echo 'address=/.test/127.0.0.1' >> $(brew — prefix)/etc/dnsmasq.conf`

*Start Dnsmasq as a service so it automatically starts at login*

`sudo brew services start dnsmasq`

#### Linux
Linux does not offer the option to add resolvers to `/etc/resolver`. You must add `nameserver 127.0.0.1` to `/etc/resolv.conf`. You should also uncomment `prepend domain-name-servers 127.0.0.1;` from `/etc/dhcp/dhclient.conf` to ensure that the dhclient does not override `resolv.conf`.

### Mkcert
Please consult [mkcert](https://github.com/FiloSottile/mkcert) for full installation instructions. *Note*: Once you have installed Mkcert you will likely need to restart your local machine. 

In order to create a certificate for each project ensure that you are inside the `traefik/` directory and run the following command replacing `example` with the value used for `$COMPOSER_PROJECT_NAME`:

`mkcert -cert-file certs/example-cert.pem -key-file certs/example-key.pem "example.test" "*.example.test"`

It is possible to add more domain names, if required. For example if you are adding a subdomain you would add `"dev.example.test"`. 

Once you have created your certificates you will need to restart Traefik by entering: 
`docker-compose restart traefik`
