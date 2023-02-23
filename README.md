# deploy-examples
This repository provides various examples of how to deploy Hummingbot using Docker. Hummingbot is a powerful, open-source trading bot for cryptocurrency markets, and Docker is a popular platform for building, shipping, and running distributed applications.

Using Docker for Hummingbot deployment offers several benefits, such as simplifying the installation process, enabling easy versioning and scaling, and ensuring a consistent and isolated environment for running the bot. This repository aims to help users get started with deploying Hummingbot using Docker by providing different examples that demonstrate how to set up and customize the bot according to their needs.

The repository includes multiple Docker Compose files, each showcasing a different deployment scenario, such as running Hummingbot with different exchange connectors, customizing the configuration, or integrating with other services. Additionally, the repository provides a detailed README file that guides users through the steps required to deploy Hummingbot using Docker, including how to build and run the containers, how to configure the bot, and how to monitor its performance.

This repository is intended for developers and traders who want to deploy Hummingbot using Docker and explore its features and capabilities. Contributions are welcome, and users are encouraged to share their own examples and use cases for deploying Hummingbot with Docker..

## How to navigate the repo
Each folder has a different example of how to deploy Hummingbot.
1. **Bash scripts**:
Use this repository to create standalone containers of Hummingbot and Gateway. For example, you can run the client from the source and use the gateway with it by utilizing the gateway-create.sh file. The following operations are possible using the Bash scripts:

- Create a Hummingbot container
- Update the Hummingbot image version
- Start a stopped container of Hummingbot
- Create a Gateway container
- Copy the certificates to the corresponding gateway path

2. **Simple Hummingbot Compose**
This example creates a single Hummingbot container.

3. **Autostart Hummingbot Compose**
This example is a variation of the Simple Hummingbot Compose, with the ability to autostart a script or a strategy. The `.password_verification` file contains the encrypted password, which is `a`. Follow the Troubleshooting guide provided in the `README.md` file of that folder to understand how to change it and use your password. This folder also includes a script called `format_status.py`, and a `conf_pure_mm_1.yml` file inside the conf/strategies directory. These files are necessary to autostart the bot since the environment variables `CONFIG_PASSWORD` and `CONFIG_FILE_NAME` are essential.

4. **Hummingbot Gateway Compose**
This example shows how to run Hummingbot with Gateway with just one command. The only essential thing to consider is managing the certificates.

5. **Multiple Hummingbot Gateway Compose**
This example demonstrates how to run multiple Hummingbot instances with Gateway with just one command. The only essential thing to consider is managing the certificates.

## IMPORTANT
All the docker-compose files use hummingbot/hummingbot:latest and hummingbot/gateway:latest as images to create the containers. If you are using a machine with ARM, we strongly recommend building your local image by cloning the official repository and running the command:
```
docker build -f Dockerfile.arm -t hummingbot/hummingbot:arm .
```
