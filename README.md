# Condor Deploy

Welcome to the Condor Deploy project. This guide will walk you through deploying the Condor Telegram bot along with optional trading infrastructure including the Hummingbot API and Dashboard.

## Prerequisites

- **Linux/macOS** with a terminal (Windows users need WSL2 with Ubuntu)
- **Docker** and **Docker Compose** (the installer will attempt to install these if missing)

## Architecture

This deployment includes:

- **Condor Bot** (required): Telegram bot for managing and monitoring Hummingbot trading bots
- **Hummingbot API** (port 8000): FastAPI backend service for bot operations and data management
- **PostgreSQL Database** (port 5432): Persistent storage for bot configurations and performance data  
- **EMQX Broker** (port 1883): MQTT broker for real-time bot communication and telemetry
- **Dashboard** (port 8501, optional): Streamlit-based web UI for bot management and monitoring

All services are orchestrated using Docker Compose for seamless deployment and management.

## Quick Install

Run this single command to download and launch the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/main/setup.sh | bash
```

### Installation Options

```bash
# Standard installation (Condor + API)
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/main/setup.sh | bash

# Include Dashboard
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/main/setup.sh | bash -s -- --with-dashboard
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--with-dashboard` | Include the Dashboard service in the installation |
| `-h, --help` | Show help message |

## What the Installer Does

The setup script will:

1. Check and install dependencies (git, docker, docker-compose) if needed
2. Prompt you for configuration:
   - **Telegram Bot Token** - Get this from [@BotFather](https://t.me/BotFather)
   - **Admin User ID** - Get this from [@userinfobot](https://t.me/userinfobot)
   - **OpenAI API Key** (optional) - For AI-powered features
   - **API/Dashboard credentials** - Username and password for the services
3. Clone the required repositories
4. Generate configuration files (`.env`, `docker-compose.yml`)
5. Start all services with Docker Compose

## Access Your Services

After installation, access your services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| Condor Bot | Your Telegram Bot | Send `/start` to your bot |
| Hummingbot API | http://localhost:8000/docs | Username/password from setup |
| Dashboard | http://localhost:8501 | Username/password from setup |
| EMQX Broker | http://localhost:18083 | admin / public |

## Managing Your Installation

All services are installed in the `hbot-instance` directory. Use these commands to manage them:

```bash
cd hbot-instance

# View running services
docker compose ps

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Start services
docker compose up -d

# Upgrade to latest versions
docker compose pull && docker compose up -d
```

## Configuration Files

After installation, you'll find these files in `hbot-instance/`:

| File | Purpose |
|------|---------|
| `.env` | Environment variables for all services |
| `docker-compose.yml` | Service definitions and configuration |
| `credentials.yml` | Dashboard authentication (if installed) |
| `condor/` | Condor bot data and routines |
| `hummingbot-api/` | API service data and bot configurations |

## Getting Started with Trading

1. **Add API Credentials**
   - Open the Dashboard or use the Condor bot
   - Navigate to credentials/config section
   - Add your exchange API keys (they will be encrypted)

2. **Create a Trading Configuration**
   - Use the Dashboard's Config Generator, or
   - Use Condor bot's `/config` command

3. **Deploy a Bot**
   - Select your configuration
   - Choose the Hummingbot image version
   - Start the bot instance

4. **Monitor Performance**
   - Check bot status via Dashboard or Condor
   - View real-time performance metrics
   - Adjust configurations as needed

## Upgrading

To upgrade your installation to the latest versions:

```bash
cd hbot-instance
docker compose pull
docker compose up -d
```

Or simply re-run the setup script from the original location - it will detect the existing installation and perform an upgrade.

## Troubleshooting

### Services not starting
```bash
# Check logs for errors
docker compose logs -f

# Restart all services
docker compose down && docker compose up -d
```

### Port conflicts
If you have other services using the default ports (8000, 8501, 5432, 1883), edit the `docker-compose.yml` to use different host ports.

### Condor bot not responding
- Verify your Telegram token is correct in `.env`
- Check `ADMIN_USER_ID` matches your Telegram user ID
- View Condor logs: `docker compose logs condor`

## Support

- **Documentation**: [Hummingbot Docs](https://docs.hummingbot.org)
- **Discord**: [Hummingbot Discord](https://discord.hummingbot.io)
- **GitHub Issues**: [Report bugs](https://github.com/hummingbot/deploy/issues)
