# deploy-examples
This repository provides various examples of how to deploy Hummingbot using Docker. Hummingbot is a powerful, open-source trading bot for cryptocurrency markets, and Docker is a popular platform for building, shipping, and running distributed applications.

Using Docker for Hummingbot deployment offers several benefits, such as simplifying the installation process, enabling easy versioning and scaling, and ensuring a consistent and isolated environment for running the bot. This repository aims to help users get started with deploying Hummingbot using Docker by providing different examples that demonstrate how to set up and customize the bot according to their needs.

The repository includes multiple Docker Compose files, each showcasing a different deployment scenario, such as running Hummingbot with different exchange connectors, customizing the configuration, or integrating with other services. Additionally, the repository provides a detailed README file that guides users through the steps required to deploy Hummingbot using Docker, including how to build and run the containers, how to configure the bot, and how to monitor its performance.

This repository is intended for developers and traders who want to deploy Hummingbot using Docker and explore its features and capabilities. Contributions are welcome, and users are encouraged to share their own examples and use cases for deploying Hummingbot with Docker..

## IMPORTANT
All the docker-compose files are using hummingbot/hummingbot:latest and hummingbot/gateway:latest as images to create the containers. If you are using a machine with ARM I strongly recommend you to build your local image by cloning the official repository and then running: 
docker build -f Dockerfile.arm -t hummingbot/hummingbot:arm .
This will build the image for your architecture and the performance will be better.
