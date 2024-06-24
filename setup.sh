#!/bin/bash

# Pulling the required Docker images
docker compose pull
docker pull hummingbot/hummingbot:latest

# Creating .env file with the required environment variables
echo "CONFIG_PASSWORD=a" > .env
echo "BOTS_PATH=$(pwd)" >> .env

# Running docker-compose in detached mode
docker compose up -d
