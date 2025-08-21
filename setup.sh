#!/bin/bash

# Hummingbot Deploy Setup Script
# This script sets up the deployment environment for Hummingbot Deploy
# with all necessary configuration options

set -e  # Exit on any error

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "🚀 Hummingbot Deploy Setup"
echo ""

echo -n "Config password [default: admin]: "
read CONFIG_PASSWORD
CONFIG_PASSWORD=${CONFIG_PASSWORD:-admin}

echo -n "Dashboard username [default: admin]: "
read USERNAME
USERNAME=${USERNAME:-admin}

echo -n "Dashboard password [default: admin]: "
read PASSWORD
PASSWORD=${PASSWORD:-admin}

# Set paths and defaults
BOTS_PATH=$(pwd)

# Use sensible defaults for deployment
DEBUG_MODE="false"
BROKER_HOST="localhost"
BROKER_PORT="1883"
BROKER_USERNAME="admin"
BROKER_PASSWORD="password"
DATABASE_URL="postgresql+asyncpg://hbot:hummingbot-api@localhost:5432/hummingbot_api"
CLEANUP_INTERVAL="300"
FEED_TIMEOUT="600"
AWS_API_KEY=""
AWS_SECRET_KEY=""
S3_BUCKET=""
LOGFIRE_ENV="prod"
BANNED_TOKENS='["NAV","ARS","ETHW","ETHF","NEWT"]'

echo ""
echo -e "${GREEN}✅ Using sensible defaults for MQTT, Database, and other settings${NC}"

echo ""
echo -e "${GREEN}📝 Creating .env file...${NC}"

# Create .env file with proper structure and comments
cat > .env << EOF
# =================================================================
# Hummingbot Deploy Environment Configuration
# Generated on: $(date)
# =================================================================

# =================================================================
# 🔐 Security Configuration
# =================================================================
USERNAME=$USERNAME
PASSWORD=$PASSWORD
DEBUG_MODE=$DEBUG_MODE
CONFIG_PASSWORD=$CONFIG_PASSWORD

# =================================================================
# 🔗 MQTT Broker Configuration (BROKER_*)
# =================================================================
BROKER_HOST=$BROKER_HOST
BROKER_PORT=$BROKER_PORT
BROKER_USERNAME=$BROKER_USERNAME
BROKER_PASSWORD=$BROKER_PASSWORD

# =================================================================
# 💾 Database Configuration (DATABASE_*)
# =================================================================
DATABASE_URL=$DATABASE_URL

# =================================================================
# 📊 Market Data Feed Manager Configuration (MARKET_DATA_*)
# =================================================================
MARKET_DATA_CLEANUP_INTERVAL=$CLEANUP_INTERVAL
MARKET_DATA_FEED_TIMEOUT=$FEED_TIMEOUT

# =================================================================
# ☁️ AWS Configuration (AWS_*) - Optional
# =================================================================
AWS_API_KEY=$AWS_API_KEY
AWS_SECRET_KEY=$AWS_SECRET_KEY
AWS_S3_DEFAULT_BUCKET_NAME=$S3_BUCKET

# =================================================================
# ⚙️ Application Settings
# =================================================================
LOGFIRE_ENVIRONMENT=$LOGFIRE_ENV
BANNED_TOKENS=$BANNED_TOKENS

# =================================================================
# 📁 Application Paths
# =================================================================
BOTS_PATH=$BOTS_PATH

EOF

echo -e "${GREEN}✅ .env file created successfully!${NC}"
echo ""

# Update docker-compose.yml with new credentials
echo -e "${GREEN}🔧 Updating docker-compose.yml with new credentials...${NC}"

# Update BACKEND_API_USERNAME and BACKEND_API_PASSWORD in docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    # Create a backup of the original file
    cp docker-compose.yml docker-compose.yml.backup
    
    # Update the credentials using sed
    if sed --version >/dev/null 2>&1; then
      # GNU sed
      SED_I=(-i)
    else
      # BSD sed
      SED_I=(-i '')
    fi

    sed "${SED_I[@]}" "s|BACKEND_API_USERNAME=.*|BACKEND_API_USERNAME=$USERNAME|" docker-compose.yml
    sed "${SED_I[@]}" "s|BACKEND_API_PASSWORD=.*|BACKEND_API_PASSWORD=$PASSWORD|" docker-compose.yml

    
    echo -e "${GREEN}✅ docker-compose.yml updated successfully!${NC}"
    echo -e "${BLUE}📋 Updated credentials:${NC} Username: $USERNAME, Password: $PASSWORD"
else
    echo -e "${YELLOW}⚠️  Warning: docker-compose.yml not found in current directory${NC}"
fi

echo ""

# Display configuration summary
echo -e "${BLUE}📋 Configuration Summary${NC}"
echo "======================="
echo -e "${CYAN}Security:${NC} Username: $USERNAME, Debug: $DEBUG_MODE"
echo -e "${CYAN}Broker:${NC} $BROKER_HOST:$BROKER_PORT"
echo -e "${CYAN}Database:${NC} ${DATABASE_URL%%@*}@[hidden]"
echo -e "${CYAN}Market Data:${NC} Cleanup: ${CLEANUP_INTERVAL}s, Timeout: ${FEED_TIMEOUT}s"
echo -e "${CYAN}Environment:${NC} $LOGFIRE_ENV"

if [ -n "$AWS_API_KEY" ]; then
    echo -e "${CYAN}AWS:${NC} Configured with S3 bucket: $S3_BUCKET"
else
    echo -e "${CYAN}AWS:${NC} Not configured (optional)"
fi

echo ""
echo -e "${GREEN}🐳 Pulling required Docker images...${NC}"

# Pull Docker images in parallel
docker compose pull &
docker pull hummingbot/hummingbot:latest &

# Wait for both operations to complete
wait

echo -e "${GREEN}✅ All Docker images pulled successfully!${NC}"
echo ""

# Check if password verification file exists
if [ ! -f "bots/credentials/master_account/.password_verification" ]; then
    echo -e "${YELLOW}📌 Note:${NC} Password verification file will be created on first startup"
    echo -e "   Location: ${BLUE}bots/credentials/master_account/.password_verification${NC}"
    echo ""
fi

echo -e "${GREEN}🚀 Starting Hummingbot Deploy services...${NC}"

# Start the deployment
docker compose up -d

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo ""

echo -e "Your services are now running:"
echo -e "📊 ${BLUE}Dashboard:${NC} http://localhost:8501"
echo -e "🔧 ${BLUE}API Docs:${NC} http://localhost:8000/docs"
echo -e "📡 ${BLUE}MQTT Broker:${NC} localhost:1883"
echo ""

echo -e "Next steps:"
echo "1. Access the Dashboard: http://localhost:8501"
echo "2. Configure your trading strategies"
echo "3. Monitor logs: docker compose logs -f"
echo ""
echo -e "${PURPLE}💡 Pro tip:${NC} You can modify environment variables in .env file anytime"
echo -e "${PURPLE}📚 Documentation:${NC} Check CLAUDE.md for project guidance"
echo -e "${PURPLE}🔒 Security:${NC} The password verification file secures bot credentials"
echo ""
echo -e "${GREEN}Happy Trading! 🤖💰${NC}"
