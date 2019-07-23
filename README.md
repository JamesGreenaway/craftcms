## Instructions for v2.0 coming soon. To use old version use docker image jamesgreenaway/craftcms:1.0. 🖖

```
version: "3.7"
services:
  dnsmasq:
    restart: always
    image: jpillora/dnsmasq:latest
    ports:
      - 53:53/udp
    networks:
      - traefik
    entrypoint: 
      - /bin/sh 
      - -c 
      - 'echo "address=/#/127.0.0.1" > /etc/dnsmasq.conf 
      && webproc --config /etc/dnsmasq.conf -- dnsmasq --no-daemon'
  traefik:
    restart: always
    image: traefik:v2.0.0-beta1
    ports:
      - 80:80
      - 443:443
      - 8080:8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      # - ./traefik.toml:/traefik.toml:ro
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
    depends_on:
      - dnsmasq
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
