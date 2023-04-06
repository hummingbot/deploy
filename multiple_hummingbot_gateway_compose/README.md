# Deploy Multiple Hummingbot Instances Linked to Gateway

This installs two [Hummingbot](https://github.com/hummingbot/hummingbot) instances, linked to a single [Hummingbot Gateway](https://github.com/hummingbot/gateway) instance.

## Prerequisites

This configuration requires [Docker Compose](https://docs.docker.com/compose/), a tool for defining and running multi-container Docker applications. The recommended way to get Docker Compose is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/), which includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

Docker Desktop is available on:

* [Linux](https://docs.docker.com/desktop/install/linux-install/)
* [Mac](https://docs.docker.com/desktop/install/mac-install/)
* [Windows](https://docs.docker.com/desktop/install/windows-install/)


## Apple M1/M2 and other ARM machines

If you have a recent Mac that uses Apple Silicon (M1/M2) chipset or another ARM-based machine, you need to change the image tag to ensure that you pull a container that is optimized for your chip architecture. 

Use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file. Change the tag for **both** the Hummingbot and Gateway images from `latest` to `latest-arm` to pull the images built for ARM-based machines. 

You can also comment out the each line that contains `latest` and uncomment each line that contains `latest-arm`:
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

Clone this repo or copy the `docker-compose.yml` file to a directory on your machine where you want to store your Hummingbot files. This is where your encrypted keys, scripts, trades, configs, logs, and other files related to your bots will be saved.

To link the Hummingbot and Gateway instances, you first have to generate certificates within Hummingbot and set the `GATEWAY_PASSPHRASE` variable in the YAML file.

### 1. Generate certs

Pull the latest Hummingbot and Gateway images and start instances with the following command:
```
docker-compose up -d
```

After the images have been downloaded, you should see the following output:
```
[+] Running 4/4
 ⠿ Network multiple_hummingbot_gateway_compose_default        Created
 ⠿ Container multiple_hummingbot_gateway_compose-bot-1        Started
 ⠿ Container multiple_hummingbot_gateway_compose-bot2-1       Started
 ⠿ Container multiple_hummingbot_gateway_compose-gateway-1    Started       
```

Attach to the `bot1` Hummingbot instance:
```
docker attach multiple_hummingbot_gateway_compose-bot-1
```

You should see the Hummingbot welcome screen:

![welcome screen](../welcome.png)

Set your [password](https://docs.hummingbot.org/operation/password/), which will be used to encrypt any keys you store with Hummingbot. This is the `CONFIG_PASSWORD` environment variable in your `docker-compose.yml` file.

Afterwards, run the following command to generate Gateway certificates:
```
gateway generate-certs
```

You'll be prompted for a passphrase used to generate the certificates. This is the `GATEWAY_PASSPHRASE` environment variable in your `docker-compose.yml` file.

Afterwards, Hummingbot will use the passphrase to generate the certificates and save them in the `hummingbot_files/certs` folder, where the Gateway instance will look for the certificates it needs.

Now, run `exit` to exit the client. 

### 2. Remove network

Once you're back in Bash/Terminal, run the following command to remove the Compose network:
```
docker-compose down
```

You should see the following output:
```
[+] Running 4/3 
 ⠿ Container multiple_hummingbot_gateway_compose-bot-1           Removed
 ⠿ Container multiple_hummingbot_gateway_compose-bot2-1          Removed
 ⠿ Container multiple_hummingbot_gateway_compose-gateway-1       Removed
 ⠿ Network multiple_hummingbot_gateway_compose_default           Removed
```  

### 3. Modify YAML file

Now, use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file.

We'll edit the section that defines the following environment variables:
```yaml
bot:
  # environment:
    #  - CONFIG_PASSWORD=[password]
bot2:
  # environment:
    #  - CONFIG_PASSWORD=[password]
gateway:
  # environment:
    #  - GATEWAY_PASSPHRASE=[passphrase]
```

Remove the '#' to uncomment out:
 * The two `environment:` lines
 * The `CONFIG_PASSWORD` line: add your Hummingbot password
 * The `GATEWAY_PASSPHRASE` line: add the passphrase you used to generate the certificates

The final `environment` section of the YAML file should look like this:
```yaml
bot:
  environment:
    - CONFIG_PASSWORD=[password]
bot2:
  environment:
    - CONFIG_PASSWORD=[password]
gateway:
  environment:
    - GATEWAY_PASSPHRASE=[passphrase]
```

Afterwards, save the file.

### 4. Recreate network

Now, recreate the Compose network:
```
docker-compose up -d
```

Attach to the `bot` Hummingbot instance. Note that since you have defined `CONFIG_PASSWORD` in the YAML file, you don't need to enter it again:
```
docker attach multiple_hummingbot_gateway_compose-bot-1
```

Similarly, you can attach to the `bot2` Hummingbot instance, which also uses `CONFIG_PASSWORD`
```
docker attach multiple_hummingbot_gateway_compose-bot2-1
```

Open a new Terminal/Bash window. In it, attach to the Gateway instance to see its logs:
```
docker attach multiple_hummingbot_gateway_compose-gateway-1
```

See [Gateway](https://docs.hummingbot.org/gateway/) for more details on how to configure it for use with Hummingbot.


## Useful Docker Commands

Use the commands below or use the Docker Desktop application to manage your Hummingbot and Gateway container:

### Create/Launch Compose network
```
docker-compose up -d
```

### Remove the Compose network
```
docker-compose down
```

### Update the Compose network for the latest images
```
docker-compose up --force-recreate --build -d
```

### Attach to the Hummingbot containers
```
docker attach multiple_hummingbot_gateway_compose-gateway-1 
docker attach multiple_hummingbot_gateway_compose-bot2-1
```

### Attach to the Gateway container
```
docker attach multiple_hummingbot_gateway_compose-gateway-1
```

### Detach from the container and return to command line

* Press keys <kbd>Ctrl</kbd> + <kbd>P</kbd> then <kbd>Ctrl</kbd> + <kbd>Q</kbd>

### List all containers
```
docker ps -a
```

### Stop a container
```
docker stop <instance-name>
```

### Remove a container
```
docker rm <instance-name>
```

## Notes

To simplify the example, we are sharing the local `hummingbot_files` files between the two bots. Ideally, you should have a separate folder for each bot. However, the `certs` folder should be shared between all bots.
