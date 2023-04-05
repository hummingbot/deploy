# Auto-Start Hummingbot Instance

This installs a single [Hummingbot](https://github.com/hummingbot/hummingbot) instance as a Docker container and automatically starts running a pre-configured script or strategy.

## Prerequisites

This configuration requires [Docker Compose](https://docs.docker.com/compose/), a tool for defining and running multi-container Docker applications. The recommended way to get Docker Compose is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/), which includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

Docker Desktop is available on:

* [Linux](https://docs.docker.com/desktop/install/linux-install/)
* [Mac](https://docs.docker.com/desktop/install/mac-install/)
* [Windows](https://docs.docker.com/desktop/install/windows-install/)


## Apple M1/M2 and other ARM machines

If you have a recent Mac that uses Apple Silicon (M1/M2) chipset or another ARM-based machine, you need to change the image tag to ensure that you pull a container that is optimized for your chip architecture. 

Use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file. Change the the image tag from `latest` to `latest-arm` to pull the image built for ARM-based machines. You can also comment out the line that contains `latest` and uncomment the line that contains `latest-arm`:
```
# image: hummingbot/hummingbot:latest
image: hummingbot/hummingbot:latest-arm
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

---

Auto-starting a script/strategy lets you start a bot from the command line, skipping the Hummingbot UI. However, before you can auto-start a script or strategy, you will do need two things first:
1. Set the password used to encrypt your keys (`CONFIG_PASSWORD`)
2. Define your script or strategy config file (`CONFIG_FILE_NAME`)

### 1. Set Hummingbot password

Pull the latest Hummingbot image and start it with the following command:
```
docker-compose up -d
```

After the images have been downloaded, you should see the following output:
```
[+] Running 1/1
 ⠿ Container autostart_hummingbot_compose-bot-1  Started 
 ```

Attach to the instance:
```
docker attach autostart_hummingbot_compose-bot-1
```

You should see the Hummingbot welcome screen:

![welcome screen](../welcome.png)

Set your Hummingbot [password](https://docs.hummingbot.org/operation/password/) and write it down. This is the `CONFIG_PASSWORD` environment variable in your `docker-compose.yml` file.

### 2. Define script/strategy file

You can auto-start either a Script or a Strategy.

[Scripts](https://docs.hummingbot.org/scripts/) are Python files that contain all strategy logic. 

If you define a `.py` file as `CONFIG_FILE_NAME`, Hummingbot assumes it's a script file and looks for the `.py` file in the `hummingbot_files/scripts` directory. 

See [`simple_pmm_example.py`](./hummingbot_files/scripts/simple_pmm_example.py) for an example.

[Strategies](https://docs.hummingbot.org/strategies/) are configurable strategy templates. 

If you define a `.yml` file as `CONFIG_FILE_NAME`, Hummingbot assumes it's a strategy config file and looks for the `.yml` file in the `hummingbot_files/conf/strategies` directory. 

See [`conf_pure_mm_1.yml`](./hummingbot_files/conf/strategies/conf_pure_mm_1.yml) for an example.

### 3. Modify YAML file

Now, use an IDE like [VSCode](https://code.visualstudio.com/) to edit the `docker-compose.yml` file.

We'll edit the section that defines the `CONFIG_PASSWORD` and `CONFIG_FILE_NAME` environment variables:
```yaml
    # environment:
      # - CONFIG_PASSWORD=[password]
      # - CONFIG_FILE_NAME=simple_pmm_example.py
      # - CONFIG_FILE_NAME=conf_pure_mm_1.yml
```

Remove the '#' to uncomment out:
 * The `environment:` line
 * The `CONFIG_PASSWORD` line: add the password you set earlier,
 * One of `CONFIG_FILE_NAME` lines: add your script OR strategy config file
 
 The final `environment` section of the YAML file should look like this:
```yaml
    environment:
      - CONFIG_PASSWORD=[password]
      - CONFIG_FILE_NAME=simple_pmm_example.py
```

Afterwards, save the file. 


### 4. Launch network

Now, the script or strategy will auto-start when you restart the Compose network
```
docker-compose up -d
```

You can attach to the container to inspect it running:
```
docker attach autostart_hummingbot_compose-bot-1
```


## Useful Docker Commands

Use the commands below or use the Docker Desktop application to manage your Hummingbot container:

### Create/launch Compose network
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

### Attach to the container
```
docker attach autostart_hummingbot_compose-bot-1
```

### Detach from the container and return to command line

* Press keys <kbd>Ctrl</kbd> + <kbd>P</kbd> then <kbd>Ctrl</kbd> + <kbd>Q</kbd>

### List all containers
```
docker ps -a
```

### Stop a container

```
docker-compose down
```

or:

```
docker stop <instance-name>
```

### Remove a container
```
docker rm <instance-name>
```
