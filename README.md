# Deploying Hummingbot with Docker

## Intro

This repository provides various examples of how to deploy Hummingbot using Docker Compose. [Hummingbot](https://github.com/hummingbot/hummingbot) is an open source framework that helps you build automated trading strategies, or bots that run on cryptocurrency exchanges, and [Docker Compose](https://docs.docker.com/compose/) is a tool for defining and running multi-container Docker applications

It also contains standalone bash scripts that assist you to setting up Hummingbot with Docker, but we recommend using Docker Compose instead.

## Why use Docker Compose?

Using Docker for Hummingbot deployment offers several benefits, such as simplifying the installation process, enabling easy versioning and scaling, and ensuring a consistent and isolated environment for running the bot. This repository aims to help users get started with deploying Hummingbot using Docker by providing different examples that demonstrate how to set up and customize the bot according to their needs.

The recommended way to get Docker Compose is to install [Docker Desktop](https://www.docker.com/products/docker-desktop/), which includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

Docker Desktop is available on:

* [Linux](https://docs.docker.com/desktop/install/linux-install/)
* [Mac](https://docs.docker.com/desktop/install/mac-install/)
* [Windows](https://docs.docker.com/desktop/install/windows-install/)

## Why does this repo contain?

Each folder showcases a different deployment type, such as running Hummingbot standalone, Hummingbot + Gateway, multiple instances, etc. The important files in each folder are:

* `docker-compose.yml`: A sample configuration file for that deployment type
* `README.md`: A detailed README file that guides users through the steps required to deploy Hummingbot using Docker, including how to build and run the containers, how to configure the bot, and how to monitor its performance.

## Deployment Types

### [Simple Hummingbot Compose](./simple_hummingbot_compose)

This installs a single [Hummingbot](https://github.com/hummingbot/hummingbot) instance as a Docker container.

### [Autostart Hummingbot Compose](./autostart_hummingbot_compose)

This installs a single [Hummingbot](https://github.com/hummingbot/hummingbot) instance as a Docker container and automatically starts running a pre-configured script or strategy.

### [Hummingbot Gateway Compose](./hummingbot_gateway_compose)

This installs a [Hummingbot](https://github.com/hummingbot/hummingbot) instance linked to a [Hummingbot Gateway](https://github.com/hummingbot/gateway) instance.

### [Multiple Hummingbot Gateway Compose](./multiple_hummingbot_gateway_compose)

This installs two [Hummingbot](https://github.com/hummingbot/hummingbot) instances, linked to a single [Hummingbot Gateway](https://github.com/hummingbot/gateway) instance.

### [Hummingbot Gateway Broker Compose](./hummingbot_gateway_broker_compose)

This installs a [Hummingbot](https://github.com/hummingbot/hummingbot) instance linked to a [Hummingbot Gateway](https://github.com/hummingbot/gateway) instance, along with an EMQX [Broker](https://github.com/hummingbot/brokers).

!!! note "Experimental deployment"
    This deployment is still undergoing testing, so we recommend using the standalone deployments for message brokers from the [hummingbot/brokers](https://github.com/hummingbot/brokers) repository.

## [Bash scripts (older)](./bash_scripts)

These standalone bash scripts can also assist you to setting up Hummingbot and Gateway with Docker, but we recommend using Docker Compose instead.

The following operations are possible using the bash scripts:

- Create a Hummingbot container
- Update the Hummingbot image version
- Start a stopped container of Hummingbot
- Create a Gateway container
- Copy the certificates to the corresponding gateway path

## Other Hummingbot Repos

* [Hummingbot Docs](https://github.com/hummingbot/hummingbot-site): Official documentation for Hummingbot - we welcome contributions here too!
* [Awesome Hummingbot](https://github.com/hummingbot/awesome-hummingbot): All the Hummingbot links
* [Hummingbot StreamLit Apps](https://github.com/hummingbot/streamlit-apps): Hummingbot-related StreamLit data apps and dashboards
* [Community Tools](https://github.com/hummingbot/community-tools): Community contributed resources related to Hummingbot
* [Brokers](https://github.com/hummingbot/brokers): Different brokers that can be used to communicate with multiple instances of Hummingbot
* [Deploy Examples](https://github.com/hummingbot/deploy-examples): Deploy Hummingbot in various configurations with Docker
* [Remote Client](https://github.com/hummingbot/hbot-remote-client-py): A remote client for Hummingbot in Python

## Contributions

Hummingbot belongs to its community, so we welcome contributions! Users are encouraged to submit pull requests with their own examples and use cases for deploying Hummingbot with Docker.
