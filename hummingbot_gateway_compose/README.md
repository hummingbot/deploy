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

Use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file. Change the tag for **both** the Hummingbot and Gateway images from `latest` to `latest-arm` to pull the images built for ARM-based machines. 

You can also comment out the lines that contains `latest` and uncomment the lines that contains `latest-arm`:
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

### Generate certificates

Pull the latest Hummingbot and Gateway images and start instances with the following command:
```
docker-compose up -d
```

After the images have been downloaded, you should see the following output:
```
[+] Running 3/3
 ⠿ Network hummingbot_gateway_compose_default      Created
 ⠿ Container hummingbot_gateway_compose-bot-1      Started
 ⠿ Container hummingbot_gateway_compose-gateway-1  Started       
```

Attach to the Hummingbot instance:
```
docker attach hummingbot_gateway_compose-bot-1
```

You should see the Hummingbot welcome screen:

![welcome screen](../welcome.png)

Set your [password](https://docs.hummingbot.org/operation/password/), which will be used to encrypt any keys you store with Hummingbot.

Afterwards, run the following command to generate Gateway certificates:
```
gateway generate-certs
```

You'll be prompted for a passphrase used to generate the certificates. This is the `GATEWAY_PASSPHRASE` environment variable in your `docker-compose.yml` file.

Afterwards, Hummingbot will use the passphrase to generate the certificates and save them in the `hummingbot_files/certs` folder, where the Gateway instance will look for the certificates it needs.

Now, run `stop` to exit the client. Once you're back in Bash/Terminal, run the following command to stop the Compose network:

```
docker-compose down
```

### Modify YAML file

Now, use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file.

We'll edit the section that defines the Gateway environment variables:
    # environment:
    #   - GATEWAY_PASSPHRASE=[passphrase]

Remove the '#' to uncomment out:
 * The `environment:` line
 * The `GATEWAY_PASSPHRASE` line: add the passphrase you used to generate the certificates

 The final `environment` section of the YAML file should look like this:
```yaml
    environment:
      - CONFIG_PASSWORD=[password]
      - GATEWAY_PASSPHRASE=[passphrase]
```

Afterwards, save the file.

## Recreate container

Now, restart the container and attach to it.
```
docker-compose up -d
docker attach hummingbot_gateway_compose-gateway-1
```

You should see `GATEWAY:ONLINE` in the upper-right hand corner of the Hummingbot client.

See [Gateway](https://docs.hummingbot.org/gateway/) for more details on how to configure it for use with Hummingbot.
