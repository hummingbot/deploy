# Deploy Multiple Hummingbot Instances with different profiles

This installs two [Hummingbot](https://github.com/hummingbot/hummingbot) instances and you can choose whether the bots use a **master_account** or **sub_accounts** for credentials and API keys. This is useful if you have multiple API keys or subaccounts setup on exchanges and want an easy way to switch between them. 

## Prerequisites

This configuration requires [Docker Compose](https://docs.docker.com/compose/), a tool for defining and running multi-container Docker applications. The recommended way to get Docker Compose is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/), which includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

See [Docker](../DOCKER.md) for more information about how to install and use Docker Compose, as well as helpful commands.

## Getting Started

Verify that Docker Compose is installed correctly by checking the version:

```bash
docker compose version
```

The output should be: `Docker Compose version v2.17.2` or similar. Ensure that you are using Docker Compose V2, as V1 is deprecated.


## 1. Clone the **deploy-examples** repo

Clone this repo to your machine and go to the folder:
```
git clone https://github.com/hummingbot/deploy-examples.git
cd deploy-examples/multiple_bots_setupp
```

Alternatively, copy the `docker-compose.yml` file to a directory on your machine where you want to store your Hummingbot files. 

This is the "root folder" where your encrypted keys, scripts, trades, configs, logs, and other files related to your bots will be saved.


## 2. Initial Configuration

### Create sub_account folder

Initially, both bots will use the **master_account** by default but let's say we want to configure the first bot to use the **master_account** and the second bot will use a **sub_account** with a different Hummingbot password and API keys from the master account. To do this, follow the instructions below - 

Create a new folder under the **multiple_bots_setup/credentials** folder named **sub_account**. There should now be two folders present 

```
multiple_bots_setup/
├── credentials/
│   ├── master_account/
│   └── sub_account/

```

### Modify the Docker Compose file

Open the Docker Compose file and in the **bot_2** section change the volumes for the credentials folder to point to the **sub_account** folder we just created and also comment out the **environment** & **CONFIG_PASSWORD** fields since we will be changing the password.

```bash hl_lines="5-6 12"
  bot_2:
    container_name: bot_2
    image: hummingbot/hummingbot:development
    volumes:
      - ./credentials/sub_account:/home/hummingbot/conf
      - ./credentials/sub_account/connectors:/home/hummingbot/conf/connectors
      - ./instances/bot_2/logs:/home/hummingbot/logs
      - ./instances/bot_2/data:/home/hummingbot/data
      - ./conf/scripts:/home/hummingbot/conf/scripts
      - ./conf/controllers:/home/hummingbot/conf/controllers
#    environment:
#      - CONFIG_PASSWORD=a
#      - CONFIG_FILE_NAME=v2_generic_with_controllers.py
#      - SCRIPT_CONFIG=conf_v2_generic_with_contorllers_2.yml
    logging:
      driver: "json-file"
      options:
          max-size: "10m"
          max-file: 5
    tty: true
    stdin_open: true

```

Save the changes

### Launch Hummingbot


From the root folder, run the following command to pull the image and start the instance:

```
docker compose up -d
```

After the images have been downloaded, you should see the following output:
```
[+] Running 4/4
 ⠿ Network multiple_bots_setup                                Created
 ⠿ Container bot_1                                            Started
 ⠿ Container bot_2                                            Started
 
```

```
docker attach bot_2
```

Set your preferred password, in this example let's use the letter **b** as the password for the sub_account

After setting the password, you can also proceed to enter the API keys for your sub accounts. 

Once you are done exit out of the Hummingbot client

```
exit
```

Then do **docker compose down** to exit out all the running instances

### Modify Docker Compose

Next, we want to edit the Docker Compose file again to set the password to autostart. Uncomment the **environment** field as well as the **CONFIG_PASSWORD** and enter the password we set for bot_2 which is "b"

```bash hl_lines="5-6 12"
  bot_2:
    container_name: bot_2
    image: hummingbot/hummingbot:development
    volumes:
      - ./credentials/sub_account:/home/hummingbot/conf
      - ./credentials/sub_account/connectors:/home/hummingbot/conf/connectors
      - ./instances/bot_2/logs:/home/hummingbot/logs
      - ./instances/bot_2/data:/home/hummingbot/data
      - ./conf/scripts:/home/hummingbot/conf/scripts
      - ./conf/controllers:/home/hummingbot/conf/controllers
    environment:
      - CONFIG_PASSWORD=b
#      - CONFIG_FILE_NAME=v2_generic_with_controllers.py
#      - SCRIPT_CONFIG=conf_v2_generic_with_contorllers_2.yml
    logging:
      driver: "json-file"
      options:
          max-size: "10m"
          max-file: 5
    tty: true
    stdin_open: true

```

### Relaunch Hummingbot

Make sure to save the changes made above to the Docker Compose file and start the bots by running:

```
docker compose up -d
```


To attach to any container use 

```
docker attach [container name]
```


### Adding more bots

You have now configured a bot with entirely different credentials. If you want to add more bots, you can choose which credentials they use just by changing the credentials folder and the **CONFIG_PASSWORD** field. For example, if we want to run a third bot using the **sub_account** credentials we just add the following to the Docker Compose file. 

```bash hl_lines="1-2 5-6 12"
  bot_3:
    container_name: bot_3
    image: hummingbot/hummingbot:development
    volumes:
      - ./credentials/sub_account:/home/hummingbot/conf
      - ./credentials/sub_account/connectors:/home/hummingbot/conf/connectors
      - ./instances/bot_2/logs:/home/hummingbot/logs
      - ./instances/bot_2/data:/home/hummingbot/data
      - ./conf/scripts:/home/hummingbot/conf/scripts
      - ./conf/controllers:/home/hummingbot/conf/controllers
    environment:
      - CONFIG_PASSWORD=b
#      - CONFIG_FILE_NAME=v2_generic_with_controllers.py
#      - SCRIPT_CONFIG=conf_v2_generic_with_contorllers_2.yml
    logging:
      driver: "json-file"
      options:
          max-size: "10m"
          max-file: 5
    tty: true
    stdin_open: true

```

Here we added the name of the new bot to **bot_3**, made sure the credentials volume is mapped to the **sub_account** folder and set the autostart password for **sub_account** which is **b**


## Updating to the Latest Version of Hummingbot

Hummingbot and Hummingbot Gateway are updated on a monthly basis, with each new version marked by a code release on Github and DockerHub, accompanied by the publication of comprehensive release notes. To upgrade to the most recent version, you just need to pull the `latest` Docker images.

Follow the steps below to upgrade your Hummingbot system:

1. **Ensure no containers are running**

   Before you initiate the update process, it is crucial to verify that no Docker containers are currently running. Use the following command to shut down any active containers:

   ```
   docker compose down
   ```

2. **Fetch the latest Docker image**

   Once you have confirmed that no containers are running, proceed to pull the latest Docker image. Use the following command to accomplish this:

   ```
   docker pull hummingbot/hummingbot
   ```

3. **Start the updated containers**

   Having pulled the latest Docker image, you can now start up your containers. They will be running the latest version of Hummingbot. Use the following command to start the containers:

   ```
   docker compose up -d
   ```

With these steps, you will have successfully updated your Hummingbot to the latest version.

