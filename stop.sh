#!/bin/bash

# Hummingbot Deploy Stop Script
# This script stops the deployment environment for Hummingbot Deploy

set -e  # Exit on any error

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "🛑 Hummingbot Deploy Stop Script"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Error: docker-compose.yml not found in current directory${NC}"
    echo "Please run this script from the deploy directory."
    exit 1
fi

# Show current running services
echo -e "${BLUE}📋 Currently running services:${NC}"
docker compose ps

echo ""
echo -e "${YELLOW}Choose an option:${NC}"
echo "1) Stop services (keep data) - Recommended"
echo "2) Stop and remove everything (clean slate)"
echo "3) Stop specific service"
echo "4) View logs before stopping"
echo "5) Cancel"

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo -e "${GREEN}🛑 Stopping services (keeping data)...${NC}"
        docker compose down
        echo -e "${GREEN}✅ Services stopped successfully!${NC}"
        echo -e "${BLUE}💾 Data and volumes are preserved${NC}"
        ;;
    2)
        echo ""
        echo -e "${YELLOW}⚠️  Warning: This will remove all data and volumes!${NC}"
        read -p "Are you sure? (y/N): " confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
            echo -e "${GREEN}🗑️  Stopping and removing everything...${NC}"
            docker compose down -v
            echo -e "${GREEN}✅ All services and data removed!${NC}"
        else
            echo -e "${BLUE}Operation cancelled.${NC}"
        fi
        ;;
    3)
        echo ""
        echo -e "${BLUE}Available services:${NC}"
        docker compose ps --format "table {{.Name}}\t{{.Status}}"
        echo ""
        read -p "Enter service name to stop: " service_name
        if docker compose ps | grep -q "$service_name"; then
            echo -e "${GREEN}🛑 Stopping $service_name...${NC}"
            docker compose stop "$service_name"
            echo -e "${GREEN}✅ $service_name stopped!${NC}"
        else
            echo -e "${RED}❌ Service '$service_name' not found or not running${NC}"
        fi
        ;;
    4)
        echo ""
        echo -e "${BLUE}📋 Recent logs:${NC}"
        docker compose logs --tail=20
        echo ""
        read -p "Press Enter to continue..."
        echo -e "${GREEN}🛑 Stopping services...${NC}"
        docker compose down
        echo -e "${GREEN}✅ Services stopped successfully!${NC}"
        ;;
    5)
        echo -e "${BLUE}Operation cancelled.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Stop operation completed!${NC}"
echo ""
echo -e "To restart the services, run: ${BLUE}bash setup.sh${NC}"
echo -e "To view running services: ${BLUE}docker compose ps${NC}"
echo -e "To view logs: ${BLUE}docker compose logs -f${NC}"
