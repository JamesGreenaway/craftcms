# A fully extensible development environment for running multiple sites with CraftCMS. 

*Warning: This project is still being developed! Please keep referring to this README for up-to-date instructions.*

## Description

### What is this?

At its core, this is a custom Docker image that is built with all the necessary resources to install and run [CraftCMS](https://craftcms.com/). Included, is a selection of tips that will help the user to run multiple websites at the same time with as minimal fuss as possible.    

### Why should I use it?

Setting up a development workflow can be timely. This project intends to remove this overhead and give you peace of mind that, no matter the circumstances, you can get back to work as quickly as possible. 

Spinning up a new instance of Craft is easy and each site can have its own secure domain name.

Projects can be run at the same time without worrying about port selection and at every step the user has the option to customise it to suit their needs. 

### How does it work?

This image is based on "Docker Official Images"; a curated set of Docker repositories hosted on Docker Hub. It will install Craft inside a volume whereby the user has access to all its files locally and in their entirety. Craft will link up to the official [MySQL](https://hub.docker.com/_/mysql) image and all database entries will persist locally on the host machine ensuring that no data is lost when containers are stopped. 

All external network data is routed to our containers via [Traefik](https://hub.docker.com/_/traefik). When used in tandem with [dnsmaq](http://www.thekelleys.org.uk/dnsmasq/doc.html) our containers can respond to requests using a custom domain name of our choosing and exist in in tandem on the same port.

---

## Quick Start: Running this image on localhost.

```
version: "3.7"
services:
  mysql: 
    image: mysql:5.7
    restart: always
    volumes:
      - mysql:/var/lib/mysql
    env_file: .env
  craft:
    image: jamesgreenaway/craftcms:latest
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./craft:/var/www/html/
    depends_on:
      - mysql
    ports: 
     - 80:80
volumes: 
  mysql: {}
``` 

### How to:

1. Create a `docker-compose.yml` file using the above configuration. 
1. Create a file called `.env` and add the following environment variables: 

    ```
    MYSQL_ROOT_PASSWORD=password
    MYSQL_USER=user
    MYSQL_PASSWORD=password
    MYSQL_DATABASE=exampleDatabase
    EMAIL_ADDRESS=test@test.com
    USER_NAME=admin
    PASSWORD=password
    SITE_URL=http://localhost
    COMPOSE_PROJECT_NAME=localhost
    ```

1. Run `docker-compose up -d`. 
1. Run `docker-compose logs -f craft` to view the Craft installation process. 
1. Once the installation is complete you can visit: `http://localhost:80` to see your new instance of CraftCMS running. 
1. Stop your container by running `docker-compose down`.

---

## How to run multiple sites at the same time without having to change ports. 

One frustrating thing about Docker is that, once your container is running, its respective port is unavailable for other containers to use. This means that, for every new site we create, we usually have to bind to a different port. Keeping track of all these ports can be unnecessarily complicated, so we need a solution that will allow us to run our containers on the same port without having to dance around trying to find a new one each time we create a site. 

### Traefik to the rescue.

Traefik describes itself is an open-source reverse proxy/load balancer. We can employ it as a kind of gatekeeper to all of our services. All our requests for data will go through Traefik first and Traefik will decide where to route them for us. We can give each container its own domain name and Traefik will arrange the networking for us.

```
version: "3.7"
services:
  traefik:
    restart: always
    image: traefik:v2.0.0-beta1
    ports:
      - 80:80
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: 
      --entrypoints.web.address=:80
      --providers.docker=true 
      --providers.docker.network=traefik
    networks:
      - traefik
networks:
  traefik:
    external: true
```

#### How to:

1. Create a separate directory and add a `docker-compose.yml` file inside it using the above configuration. 
1. Run `docker network create traefik` to create a custom network. 
1. Run `docker-compose up -d` to start the container. 

Next, we need to alter our other `docker-compose.yml` file to depend on Traefik.

```
version: "3.7"
services:
  mysql: 
    image: mysql:5.7
    restart: always
    volumes:
      - mysql:/var/lib/mysql
    env_file: .env
  craft:
    image: jamesgreenaway/craftcms:latest
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./craft:/var/www/html/
    labels:
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.entrypoints=web
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.rule=Host(
        `localhost`)
    depends_on:
      - mysql
    networks:
      - default 
      - traefik
volumes: 
  mysql: {}
networks:
  traefik:
    external: true
``` 

#### How to: 

1. Amend the original compose file so that it matches the configuration above.
1. Run `docker-compose up -d` to start our containers. 
1. Now you can visit `http://localhost:80` to see your instance of CraftCMS running. The container is still running on `localhost:80`, however, Traefik is now intercepting all requests to this port and sending them to our container.

>  Remember to stop all containers before continuing.

## Giving each site its own domain name.

Currently we have one site running on localhost via Traefik, however, to have multiple sites running alongside each other we need more freedom. [dnsmasq](https://wiki.debian.org/HowTo/dnsmasq) can help us to redirect all domains that end in a specific top-level domain (i.e. `.test`) back to our local machine. Traefik can then decide which container to send it to based on its subdomain.

1. Run `brew install dnsmasq` (macOS) to install dnsmaq. 
1. Tell dnsmaq to look out for any domains that end in `.test`: 

    ```
    mkdir -p /etc/resolver
    echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolver/test > /dev/null
    echo 'address=/.test/127.0.0.1' >> $(brew — prefix)/etc/dnsmasq.conf
    ```

1. Start dnsmasq as a service so it automatically starts at login `sudo brew services start dnsmasq` (macOS).

> #### *Note*:
>
> For Liunx (Debian/Ubuntu) users, you can install dnsmaq using `apt-get install dnsmasq`. 
>
> You can then edit dnsmasq config file `echo 'address=/.test/127.0.0.1' >> /etc/dnsmasq.conf`. 
>
> Linux, however, does not offer the option to add resolvers to `/etc/resolver`. Instead you must uncomment `prepend domain-name-servers 127.0.0.1;` from `/etc/dhcp/dhclient.conf` to ensure that the dhclient overrides `resolv.conf` with our localhost's IP address. In some cases (i.e. ChromeOS' Crostini) you may also need to feed the `dhclient.conf` file with Google's public DNS servers like so: `prepend domain-name-servers 127.0.0.1,8.8.8.8,8.8.4.4;`. 
>
> You will also need to restart your local machine to run the dhclient script which will then subseqently override the `resolv.conf` file with our nameservers.

Now we need to update our craft container to include its own custom domain name. 

1. Edit the Host rule label inside the `docker-compose.yml` file so that it matches the following configuration:

    ```
    - traefik.http.routers.${COMPOSE_PROJECT_NAME}.rule=Host(
      `${COMPOSE_PROJECT_NAME}.test`)
    ```

1. Change the value of the following environment variables in our `.env` file: 

    ```
    SITE_URL=http://example.test
    COMPOSE_PROJECT_NAME=example
    ```

1. Next, we need to remove the old craft project and its respective mysql volume so that we can re-install a new Craft project using the new domain names. 
    > You could manually change the settings inside the Craft dashboard but, for now, let's just create a new project. 

    ```
    rm -rf ./craft
    docker volume rm localhost_mysql
    ```

1. Run `docker-compose up -d` to start our container. 
1. Once installed you can visit `http://example.test` to see your instance of Craft running.
>  Remember to stop all containers before continuing.

You can now run as many sites as you wish. All our sites will be running on the same port and Traefik will route each site's data to its respective container by matching them to their given domain names. 

## Let's add HTTPS.

To mimic a secure HTTPS-enabled site, we can use [mkcert](https://github.com/FiloSottile/mkcert). mkcert can  fabricate self-signed SSL certificates super-quick and with zero configuration. 

Please consult the [mkcert](https://github.com/FiloSottile/mkcert) Github repository for full installation instructions. 

> *Note*: Once you have installed mkcert you will likely need to restart your local machine. 

To create a certificate, create a folder called `certificates/` inside the same directory we ran Traefik from and run the following command altering the subdomain as necessary: 

```
mkcert -cert-file certificates/example-cert.pem -key-file certificates/example-key.pem "example.test" "*.example.test"
```
Once you have created your certificates you will need to inform Traefik of where it can locate them. Please add a file called `dynamic_conf.toml` and include the following text for each project you create certificates for:

```
[tls]
  [[tls.certificates]]
    certFile = "/certificates/example-cert.pem"
    keyFile = "/certificates/example-key.pem"
```
> Make sure that you edit the word `example` to match the environment variable `$COMPOSE_PROJECT_NAME`. 
>
> Hopefully this step will not be necessary in the future when Traefik v2.0 is out of beta. [#5169](https://github.com/containous/traefik/issues/5169)

Now we need to update both containers to include this feature. Let's start by editing Traefik's compose file.

1. Expose port 443 by adding the following value to the `ports` option:

    `- 443:443`

1. Add two more volumes to the `volumes` configuration option: 

    ```
    - ./dynamic_conf.toml:/config/dynamic_conf.toml:ro
    - ./certificates:/certificates:ro
    ```

1. Add the following `command` flags: 

    ```
    --entrypoints.web-secure.address=:443
    --providers.file.filename=/config/dynamic_conf.toml
    --providers.file.watch=true
    ```

1. Run `docker-compose up -d` to run the container. 

1. Now, we need to edit our `docker-compose.yml` file for Craft.  Add the following flags to the `labels` configuration option: 

    ```
    - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.tls=true
    - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.entrypoints=web-secure
    - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.rule=Host(
      `${COMPOSE_PROJECT_NAME}.test`)
    ```

1. Finally, update the `$SITE_URL` environment variable to `https://`:

    `SITE_URL=https://example.test`

1. Run `docker-compose up -d` to run the container.

1. You can now visit `https://example.test` to see your instance of CraftCMS running using the HTTPS protocol.

---

## Other Features

### Using a local cache for composer. 

To help reduce the time it takes to install a new Craft project you can add a volume to our `craft` service that will store Composer's cache locally on the host machine. Here we are linking it to `~/.composer`: 

`- $HOME/.composer:/home/craft/.composer`

*Important*: Please ensure that the file you choose to host Composer's cache has read/write/execute access for all users by running `chmod 777 .composer`.

---

### Redirect to HTTPS.

If you would like your site to always redirect to HTTPS you can add the following middleware to the `craft` services labels: 

```
- traefik.http.routers.${COMPOSE_PROJECT_NAME}.middlewares=https
- traefik.http.middlewares.https.redirectscheme.scheme=https
```

Now our domain will always redirect back to the HTTPS protocol.

---

### How to migrate an existing project.

To migrate an existing project you must clone your repository inside a directory called `craft` and add the following environment variable to Docker's `.env` file:

`SECURITY-KEY=<thirty-two-characters>`
>This must match the existing project.

The docker image will run `composer update` to install all the dependencies when it cannot find a `/vendors` directory. Craft's `.env` file will be auto-populated with our project's environment variables. 

---

### Exporting and importing databases.

* `docker exec <container-name> sh -c 'exec mysqldump <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' > mysqldump.sql`
> This will take an existing database and dump the contents of the database in a file named mysqldump.sql

* `docker exec -i <container-name> sh -c 'exec mysql <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' < mysqldump.sql`
> This will take an existing mysqldump.sql and dump its contents in to a database of your choosing.

* `docker exec <container-name> sh -c 'exec mysqldump <database> -uroot -p"$MYSQL_ROOT_PASSWORD"' | ssh <remote_server> mysql -uroot <database>`
> This will take an existing database and dump the contents of the database in to a named database on a remote server

* `ssh <remote_server> mysqldump <database> | docker exec -i <container-name> sh -c 'exec mysql <database> -uroot -p"$MYSQL_ROOT_PASSWORD"'`
> This will take a existing database on a remote server and dump the contents inside named local database. 

---

### Building the image with alternative arguments.

It is also possible to build this image with some additional arguments. This can alter some of the lower level settings that are already predetermined when using the default image. You need to reference the Github repository as a context and add the arguments to the `docker-compose.yml` file. For example: 

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
> This image has been created to be environment agnostic, the current default is `development` however, if you need to run this in a production environment you can use `production`. This will set the `php.ini` file so that it is ready for production. 

You can then run `docker-compose up --build -d` to build and run your container with the new argument values. 

--- 

## Reference

### Environment Variables 

* `MYSQL_ROOT_PASSWORD=password`
> Needed so that the Craft instance can create database entries.
* `MYSQL_USER=user`
> Needed so that the Craft instance can create database entries.
* `MYSQL_PASSWORD=password`
> Needed so that the Craft instance can create database entries.
* `MYSQL_DATABASE=uniqueDatabaseName`
> Creates a database using this name. Grants all privileges to `$MYSQL_USER`.
* `DATABASE_TABLE_PREFIX=craft`
> *Optional*: Sets the table prefix for the Craft database.  
* `EMAIL_ADDRESS=test@test.com`
> Sets the email address for Craft dashboard.
* `USER_NAME=admin`
> Sets the username for Craft dashboard.
* `PASSWORD=password`
> Sets the password for Craft dashboard.
* `SITE_URL=https://example.test`
> Sets the website name inside Craft and is also used as a basis to set the `ServerName` and `ServerAlias` for Apache's Virtual Hosts.
* `LANGUAGE=en`
> *Optional*: Sets the system language for Craft dashboard.
* `COMPOSE_PROJECT_NAME=example`
> *Important*: This variable serves to set the name of the whole project and the projects name on Craft's dashboard. It is also used in the `docker-compose.yml` file to set the name of the routers and Host rules for Traefik, this is done simply as a convenience measure.
* `SECURITY-KEY=<thirty-two-characters>`
> *Note*: This should only be used when migrating an exiting project. The value must match the existing project's security key.

## Example Project

Here is an example of a typical project for your reference: 

`/traefik/docker-compose.yml`:

```
version: "3.7"
services:
  traefik:
    restart: always
    image: traefik:v2.0.0-beta1
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./dynamic_conf.toml:/config/dynamic_conf.toml:ro
      - ./certificates:/certificates:ro
    command: 
      --entrypoints.web.address=:80
      --providers.docker=true 
      --providers.docker.network=traefik
      --entrypoints.web-secure.address=:443
      --providers.file.filename=/config/dynamic_conf.toml
      --providers.file.watch=true
    networks:
      - traefik
networks:
  traefik:
    external: true
```

`/traefik/dynamic_conf.toml`:

```
[tls]
  [[tls.certificates]]
    certFile = "/certificates/example-cert.pem"
    keyFile = "/certificates/example-key.pem"
```

`/example/docker-compose.yml`:

```
version: "3.7"
services:
  mysql: 
    image: mysql:5.7
    restart: always
    volumes:
      - mysql:/var/lib/mysql
    env_file: .env
  craft:
    image: jamesgreenaway/craftcms:latest
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./craft:/var/www/html/
      - ./virtualhost.conf:/etc/apache2/sites-available/000-default.conf
      - $HOME/.composer:/home/craft/.composer
    labels:
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.entrypoints=web
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.rule=Host(
        `${COMPOSE_PROJECT_NAME}.test`, `www.${COMPOSE_PROJECT_NAME}.test`)
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.tls=true
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.entrypoints=web-secure
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-secure.rule=Host(
        `${COMPOSE_PROJECT_NAME}.test`, `www.${COMPOSE_PROJECT_NAME}.test`)
      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.middlewares=https
      - traefik.http.middlewares.https.redirectscheme.scheme=https
    depends_on:
      - mysql
    networks:
      - default 
      - traefik
volumes: 
  mysql: {}
networks:
  traefik:
    external: true
``` 

`/example/.env`:

```    
MYSQL_ROOT_PASSWORD=password
MYSQL_USER=user
MYSQL_PASSWORD=password
MYSQL_DATABASE=exampleDatabase
EMAIL_ADDRESS=test@test.com
USER_NAME=admin
PASSWORD=password
SITE_URL=https://example.test
COMPOSE_PROJECT_NAME=example
```
