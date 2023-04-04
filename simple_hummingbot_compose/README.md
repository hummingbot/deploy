# Deploy a single Hummingbot instance with Docker Compose

This installs a single [Hummingbot](https://github.com/hummingbot/hummingbot) instance.

## Prerequisites

This configuration requires [Docker Compose](https://docs.docker.com/compose/), a tool for defining and running multi-container Docker applications. The recommended way to get Docker Compose is to install Docker Desktop, wihch includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

Docker Desktop is available on:

* [Linux](https://docs.docker.com/desktop/install/linux-install/)
* [Mac](https://docs.docker.com/desktop/install/mac-install/)
* [Windows](https://docs.docker.com/desktop/install/windows-install/)

## Installation

Clone this repo or copy the `docker-compose.yml` file to a directory on your machine where you want to store your Hummingbot files. This is where your encrypted keys, scripts, trades, and log files will be saved.

From that directory, run `docker-compose up -d` to pull the image and start the instance. In Terminal/Bash, you should see:

```
[+] Running 1/1
 ⠿ Container simple_hummingbot_compose-bot-1  Started 
 ```

After it's running, attach to the instance with `docker attach simple_hummingbot_compose-bot-1`.

If installation was successful, you should see the Hummingbot welcome screen:

![welcome screen](../welcome.png)

Next, explore the Hummingbot [features](https://docs.hummingbot.org/operation/) or follow the [quickstart guide](https://docs.hummingbot.org/quickstart/).


## Basic commands

Use the commands below or use Docker Desktop application to manage your Hummingbot instance:

Create the instance:
```
docker-compose up -d
```

Attach to the instance:
```
docker attach simple_hummingbot_compose-bot-1
```

Detach from the instance and return to command line:

Press keys <kbd>Ctrl</kbd> + <kbd>P</kbd> then <kbd>Ctrl</kbd> + <kbd>Q</kbd>

See all instances:
```
docker ps -a
```

Stop an instance:
```
docker stop <instance-name>
```

Remove an instance:
```
docker rm <instance-name>
```
