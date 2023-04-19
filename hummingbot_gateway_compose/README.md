# Deploy Hummingbot and Gateway Instances

This installs a [Hummingbot](https://github.com/hummingbot/hummingbot) instance linked to a [Hummingbot Gateway](https://github.com/hummingbot/gateway) instance.

## Prerequisites

This configuration requires [Docker Compose](https://docs.docker.com/compose/), a tool for defining and running multi-container Docker applications. The recommended way to get Docker Compose is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/), which includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

See [Docker](../DOCKER.md) for more information about how to install and use Docker Compose, as well as helpful commands.

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

Installing Hummingbot alongside Gateway lets you access data and execute orders on DEX connectors.

To enable this, you will do need a few things first:
- Install and configure the Hummingbot and Gateway instances
- Generate self-signed certificates in Hummingbot
- Give Gateway the passphrase used to generate the certificates (`GATEWAY_PASSPHRASE`)

First, let's check that you have installed Docker Compose successfully. In Terminal/Bash, Run the following command:
```
docker compose
```

You should see a response that start with:
```
Usage:  docker compose [OPTIONS] COMMAND
```

### 1. Launch network

Clone this repo to your machine and go to the folder:
```
git clone https://github.com/hummingbot/deploy-examples.git
cd deploy-examples/hummingbot_gateway_compose
```

Alternatively, copy the `docker-compose.yml` file to a directory on your machine where you want to store your Hummingbot files. 

This is the "root folder" where your encrypted keys, scripts, trades, configs, logs, and other files related to your bots will be saved.

From the root folder, run the following command to pull the image and start the instance:
```
docker compose up -d
```

After the images have been downloaded, you should see the following output:
```
[+] Running 3/3
 ⠿ Network hummingbot_gateway_compose_default     Created
 ⠿ Container hummingbot                           Started
 ⠿ Container gateway                              Started       
```

### 2. Set permissions

Run this command from your root folder to grant read/write permission to the `hummingbot_files` and `gateway_files` sub-folders:
```
sudo chmod -R a+rw ./hummingbot_files ./gateway_files
```

### 3. Launch Hummingbot and generate certificates

Now, attach to the `hummingbot` instance:
```
docker attach hummingbot
```

You should see the Hummingbot welcome screen:

![welcome screen](../welcome.png)

Set your Hummingbot [password](https://docs.hummingbot.org/operation/password/) and write it down. This is the `CONFIG_PASSWORD` environment variable in your `docker-compose.yml` file.

Run the following command to generate Gateway certificates:
```
gateway generate-certs
```

You'll be prompted for a passphrase used to generate the certificates. This is the `GATEWAY_PASSPHRASE` environment variable in your `docker-compose.yml` file.

Hummingbot will use the passphrase to generate the certificates and save them in the `hummingbot_files/certs` folder, where the Gateway instance will look for the certificates it needs.

Afterwards, run `exit` to exit Hummingbot.

### 4. Remove network

Once you're back in Bash/Terminal, run the following command to remove the Compose project:
```
docker compose down
```

You should see the following output:
```
[+] Running 3/3 
 ⠿ Container gateway                            Removed
 ⠿ Container hummingbot                         Removed
 ⠿ Network hummingbot_gateway_compose_default   Removed
```  

### 5. Modify YAML file

Now, use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file.

Edit the section that defines the `CONFIG_PASSWORD` and `CONFIG_FILE_NAME` environment variables:
```yaml
  hummingbot:
    # environment:
      #  - CONFIG_PASSWORD=[password]
  gateway:
    # environment:
      #  - GATEWAY_PASSPHRASE=[passphrase]
```

Uncomment out:
 * The `environment:` lines
 * The `CONFIG_PASSWORD` lines: add your Hummingbot password
 * The `GATEWAY_PASSPHRASE` line: add the passphrase you used to generate the certificates

The final `environment` section of the YAML file should look like this:
```yaml
  hummingbot:
    environment:
      - CONFIG_PASSWORD=[password]
  gateway:
    environment:
      - GATEWAY_PASSPHRASE=[passphrase]
```

Afterwards, save the file.

### 6. Recreate network

Now, recreate the Compose project:
```
docker compose up -d
```

Attach to the `hummingbot` instance. If you have defined `CONFIG_PASSWORD` in the YAML file, you don't need to enter it again:
```
docker attach hummingbot
```
After you enter your password, you should now see `GATEWAY:ONLINE` in the upper-right hand corner.

Open a new Terminal/Bash window. In it, attach to the `gateway` instance to see its logs:
```
docker attach gateway
```
See [Gateway](https://docs.hummingbot.org/gateway/) for more details on how to configure it for use with Hummingbot.

To get started with Hummingbot, check out the following docs:

* [Basic Features](https://docs.hummingbot.org/operation/)
* [Quickstart Guide](https://docs.hummingbot.org/quickstart/)
* [Hummingbot FAQ](https://docs.hummingbot.org/faq/)
