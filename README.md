# Condor Deploy

Welcome to the Hummingbot Deploy repo. This repo contains bash script(s) that automate installing Condor + Hummingbot API

## Prerequisites

- **Linux/macOS** with a terminal (Windows users need WSL2 with Ubuntu)
- **Docker** and **Docker Compose** (the installer will install these if missing)
- **Make** and **Git** (the installer will install these if missing)
- **Conda/Anaconda** (required only for Hummingbot API; installer will offer to install if needed)

## Architecture

This deployment includes:

- **Condor Bot** (required): Telegram bot for managing and monitoring Hummingbot trading bots
- **Hummingbot API** (optional, port 8000): FastAPI backend service for bot operations and data management
- **PostgreSQL Database** (port 5432, if API installed): Persistent storage for bot configurations and performance data  
- **EMQX Broker** (port 1883, if API installed): MQTT broker for real-time bot communication and telemetry

Each repository manages its own Docker Compose configuration and setup process via Makefile. The installer orchestrates the complete deployment workflow.

## Quick Install

Run this single command to download and launch the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash
```

### Installation Options

```bash
# Fresh installation (installs Condor first, then optionally API)
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash

# Upgrade existing installation
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash -s -- --upgrade

```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--upgrade` | Upgrade existing installation or install missing components |
| `-h, --help` | Show help message and usage examples |

## What the Installer Does

The setup script will:

1. **Detect OS & Architecture** - Identifies your operating system (Linux/macOS) and CPU architecture (x86_64/ARM64)
2. **Install Dependencies** - Checks and installs missing tools:
   - Git
   - Docker
   - Docker Compose
   - Make (build-essentials)
3. **Clone Condor Repository** - Downloads the Condor bot source code
4. **Setup Condor** - Runs `make setup` to initialize Condor environment variables and configurations
5. **Deploy Condor** - Runs `make deploy` to start the Condor service
6. **Prompt for API Installation** - Asks if you want to install Hummingbot API
   - If yes:
     - Checks for Conda (offers to install Anaconda if missing)
     - Clones Hummingbot API repository
     - Runs `make setup` to configure API environment
     - Runs `make deploy` to start the API service

## Installation Flow

### Fresh Installation

```
1. Start setup script
   ↓
2. Check & install dependencies
   ↓
3. Clone Condor repository
   ↓
4. Run: make setup (Condor)
   ↓
5. Run: make deploy (Condor)
   ↓
6. Prompt: Install Hummingbot API?
   ├─ No → Installation complete
   └─ Yes → Check for Conda
      ├─ If missing → Install Anaconda (with auto-shell restart)
      ├─ Clone Hummingbot API
      ├─ Run: make setup (API)
      └─ Run: make deploy (API) → Installation complete
```

### Upgrade Installation

```
1. Start with --upgrade flag
   ↓
2. Check & install dependencies (if needed)
   ↓
3. If Condor exists → git pull (update code)
   ↓
4. If API exists → git pull (update code)
   ├─ If API doesn't exist → Prompt to install
   └─ If yes → Clone, setup, and deploy
   ↓
5. Pull latest Docker images (Condor & API only)
   ↓
6. Restart services
   ↓
7. Display status
```

## Directory Structure

After installation, your deployment directory will contain:

```
.
├── condor/                    # Condor bot repository
│   ├── docker-compose.yml     # Condor's service configuration
│   ├── .env                   # Environment variables (managed by Condor)
│   ├── config.yml             # Condor configuration
│   └── routines/              # Custom bot routines
│
└── hummingbot-api/            # Hummingbot API repository (if installed)
    ├── docker-compose.yml     # API's service configuration
    ├── .env                   # Environment variables (managed by API)
    └── bots/                  # Bot instances and configurations
```

## Accessing Your Services

After installation, access your services at:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Condor Bot | Your Telegram Bot | Send `/start` to your bot |
| Hummingbot API | http://localhost:8000/docs | Set during installation |
| PostgreSQL | localhost:5432 | Set during installation |
| EMQX Dashboard | http://localhost:18083 | admin / public |

## Managing Your Installation

Since each repository manages its own Docker Compose, use these commands:

### Condor Bot

```bash
cd condor

# View running Condor service
docker compose ps

# View logs
docker compose logs -f

# Stop Condor
docker compose down

# Start Condor
docker compose up -d

# Upgrade Condor
docker compose pull && docker compose up -d
```

### Hummingbot API (if installed)

```bash
cd hummingbot-api

# View running API services
docker compose ps

# View logs
docker compose logs -f

# Stop all API services (API, PostgreSQL, EMQX)
docker compose down

# Start all API services
docker compose up -d

# Upgrade API services
docker compose pull && docker compose up -d
```

## Getting Started with Trading

1. **Add Exchange API Credentials**
   - Send `/credentials` command to Condor bot, or
   - Access the API directly at http://localhost:8000/docs
   - Add your exchange API keys (they will be encrypted)

2. **Create a Trading Configuration**
   - Use Condor bot's `/config` command, or
   - Use the API's configuration endpoints
   - Define your trading strategy and parameters

3. **Deploy a Bot**
   - Send `/deploy` command to Condor bot
   - Select your configuration
   - Monitor bot status in real-time

4. **Monitor Performance**
   - Check bot status via Condor bot
   - View API logs for detailed information
   - Access raw metrics via API endpoints

## Upgrading

To upgrade your installation to the latest versions:

### Option 1: Re-run the installer (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash -s -- --upgrade
```

### Option 2: Manual upgrade

```bash
# Upgrade Condor
cd condor
git pull
docker compose pull
docker compose up -d

# Upgrade Hummingbot API (if installed)
cd ../hummingbot-api
git pull
docker compose pull
docker compose up -d
```

## Troubleshooting

### Services not starting

```bash
# Check Condor logs
cd condor && docker compose logs -f

# Check API logs (if installed)
cd ../hummingbot-api && docker compose logs -f
```

### Condor bot not responding

- Verify your Telegram Bot Token is correct
- Check `ADMIN_USER_ID` matches your Telegram user ID
- Ensure Condor container is running: `cd condor && docker compose ps`

### API connection issues

- Verify API container is running: `cd hummingbot-api && docker compose ps`
- Check PostgreSQL and EMQX are healthy
- Review API logs: `cd hummingbot-api && docker compose logs hummingbot-api`

### Port conflicts

If you have other services using the default ports, edit the respective `docker-compose.yml`:

- **Condor**: Uses host network (no port conflicts)
- **API**: Default ports are 8000 (API), 5432 (PostgreSQL), 1883 (EMQX)

### Conda installation issues

If Anaconda installation fails:

1. Install manually from https://www.anaconda.com/download
2. Ensure conda is in your PATH: `conda --version`
3. Re-run the installer with `--upgrade` flag

## Support

- **Documentation**: [Hummingbot Docs](https://docs.hummingbot.org)
- **Discord**: [Hummingbot Discord](https://discord.hummingbot.io)
- **GitHub Issues**: [Report bugs](https://github.com/hummingbot/deploy/issues)

## Advanced Configuration

### Modifying Environment Variables

Each repository manages its own `.env` file. To modify settings:

```bash
# Edit Condor environment
cd condor
nano .env
docker compose restart

# Edit API environment (if installed)
cd ../hummingbot-api
nano .env
docker compose restart
```

### Customizing Condor Routines

Add custom trading routines to `condor/routines/`:

```bash
cd condor/routines
# Add your .py files here
docker compose restart
```

### Managing PostgreSQL Data

API data is stored in Docker volumes. To backup:

```bash
cd hummingbot-api
docker compose exec postgres pg_dump -U hbot hummingbot_api > backup.sql
```

To restore:

```bash
cd hummingbot-api
cat backup.sql | docker compose exec -T postgres psql -U hbot hummingbot_api
```

## License

Hummingbot Deploy is licensed under the HUMMINGBOT OPEN SOURCE LICENSE AGREEMENT. See LICENSE file for details.
