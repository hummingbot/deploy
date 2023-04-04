# Deploy Hummingbot and Gateway Instances

This installs [Hummingbot](https://github.com/hummingbot/hummingbot) and [Hummingbot Gateway](https://github.com/hummingbot/gateway) as linked Docker containers.

## Prerequisites

This configuration requires [Docker Compose](https://docs.docker.com/compose/), a tool for defining and running multi-container Docker applications. The recommended way to get Docker Compose is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/), which includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

Docker Desktop is available on:

* [Linux](https://docs.docker.com/desktop/install/linux-install/)
* [Mac](https://docs.docker.com/desktop/install/mac-install/)
* [Windows](https://docs.docker.com/desktop/install/windows-install/)


## Apple M1/M2 and other ARM machines

If you have a recent Mac that uses Apple Silicon (M1/M2) chipset or another ARM-based machine, you need to change the image tag to ensure that you pull a container that is optimized for your chip architecture. 

Use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file. Change the the tag for both the Hummingbot and Gateway images from `latest` to `latest-arm` to pull the image built for ARM-based machines. 

You can also comment out the line that contains `latest` and uncomment the lines that contains `latest-arm`:
```
# image: hummingbot/hummingbot:latest
image: hummingbot/hummingbot:latest-arm

# image: hummingbot/gateway:latest
image: hummingbot/gateway:latest-arm
```

Afterwards, save the file and proceed to the next step.

If you are using a Mac with an Intel (x86) chipset, Windows or any other Intel-based machine, you don't need to make any changes before deploying a container.

## Getting Started

If you have installed Docker Compose successfully, the `docker-compose` command should be available in Terminal/Bash:
```
docker-compose
```

You should see a response that start with:
```
Usage:  docker compose [OPTIONS] COMMAND
```

You will need to have the certificates for the gateway and hummingbot under the folder hummingbot_files/certs. If you don't have it, don't worry, you can generate them with the client by doing the following:

- Make sure you have docker and docker-compose installed.
- Run the following command in the terminal:

    ```
    docker-compose up -d
    ```

- You will see that the gateway failed to start because you don't have the certificates
- Attach the instance of the bot by running:

    ```
    docker attach hummingbot_gateway_compose-bot-1
    ```

- Create the password
- Run the following command in the client:

    ```
    gateway generate-certs
    ```

- When prompted enter the passphrase that you want. Is important that you change the docker-compose.yml on line 18 to the passphrase that you entered (the current passphrase is `a`).
- Exit the client and run the following command in the terminal:

    ```
    docker-compose down
    ```

- You will see that inside the hummingbot_files/certs folder you have the certificates.
- We are ready to deploy the gateway and hummingbot, run the following command in the terminal:

    ```
    docker-compose up -d
    ```

- If you attach the terminal of the gateway you will see that it is running.

    ```
    docker attach hummingbot_gateway_compose-gateway-1
    ```

- If you attach the terminal of the bot you will see that it is running and the gateway is ONLINE.

    ```
    docker attach hummingbot_gateway_compose-bot-1
    ```
