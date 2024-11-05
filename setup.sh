#!/bin/bash

function show_menu() {
  clear
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║                    Installation Options                    ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  echo "[1] Use recommended settings [default]"
  echo "    - Installs all components with default configurations"
  echo ""
  echo "[2] Use dYdX branch"
  echo "    - Installs the Hummingbot Dashboard version tailored for dYdX"
  echo ""
  echo "[3] Dashboard only"
  echo "    - Installs only the Dashboard interface"
  echo ""
  echo "[4] Backend-API only"
  echo "    - Installs only the Backend-API service"
  echo ""
  echo "[5] Broker Only"
  echo "    - Installs only the EMQX broker service"
  echo ""
  echo "[6] Hummingbot Client Only"
  echo "    - Installs only the Hummingbot CLI client using the 'latest' tag"
  echo ""
  echo "[7] Exit"
  echo "    - Exits the setup process"
  echo ""
}

while true; do
  show_menu
  read -p "Please select an option [1-7] or press Enter for default (1): " choice
  choice=${choice:-1}  # Set default value to 1 if choice is empty

  case $choice in
    1)
      echo "Using default settings..."
      # Pulling the required Docker images
      docker compose pull
      docker pull hummingbot/hummingbot:latest

      # Check if .env exists before creating
      if [ ! -f .env ]; then
        echo "CONFIG_PASSWORD=a" > .env
        echo "BOTS_PATH=$(pwd)" >> .env
      else
        echo ".env already exists, skipping creation."
      fi

      # Running docker-compose in detached mode
      docker compose up -d

      # Clear screen and show completion message
      clear
      echo "╔════════════════════════════════════════════════════════════╗"
      echo "║                 Installation Complete!                     ║"
      echo "╚════════════════════════════════════════════════════════════╝"
      echo ""
      echo " You can now view Hummingbot Dashboard in your browser."
      echo ""
      echo " Network URL: http://localhost:8501"
      echo " Alternate URL: http://127.0.0.1:8501"
      echo ""
      echo " Backend API running on http://localhost:8000"
      echo " Swagger Docs: http://localhost:8000/docs"
      echo ""
      echo " For more documentation on how to use Dashboard "
      echo " https://hummingbot.org/dashboard"
      echo ""
      echo " To stop all services, run:"
      echo " docker compose down"
      echo ""
      exit 0
      ;;
    2)
      echo "Using dYdX branch..."
      docker pull hummingbot/hummingbot:latest_dydx --quiet 
      # Create a permanent docker-compose file for dYdX
      cat > docker-compose.dydx.yml << 'EOL'
services:
  dashboard:
    container_name: dashboard
    image: hummingbot/dashboard:dydx
    ports:
      - "8501:8501"
    volumes:
      - ./credentials.yml:/home/dashboard/credentials.yml
      - ./pages:/home/dashboard/frontend/pages
    networks:
      - emqx-bridge

  backend-api:
    container_name: backend-api
    image: hummingbot/backend-api:dydx
    ports:
      - "8000:8000"
    volumes:
      - ./bots:/backend-api/bots
      - /var/run/docker.sock:/var/run/docker.sock
    env_file:
      - .env
    networks:
      - emqx-bridge

emqx:
    container_name: hummingbot-broker
    image: emqx:5
    restart: unless-stopped
    environment:
      - EMQX_NAME=emqx
      - EMQX_HOST=node1.emqx.local
      - EMQX_CLUSTER__DISCOVERY_STRATEGY=static
      - EMQX_CLUSTER__STATIC__SEEDS=[emqx@node1.emqx.local]
      - EMQX_LOADED_PLUGINS="emqx_recon,emqx_retainer,emqx_management,emqx_dashboard"
    volumes:
      - emqx-data:/opt/emqx/data
      - emqx-log:/opt/emqx/log
      - emqx-etc:/opt/emqx/etc
    ports:
      - "1883:1883"  # mqtt:tcp
      - "8883:8883"  # mqtt:tcp:ssl
      - "8083:8083"  # mqtt:ws
      - "8084:8084"  # mqtt:ws:ssl
      - "8081:8081"  # http:management
      - "18083:18083"  # http:dashboard
      - "61613:61613"  # web-stomp gateway
    networks:
      emqx-bridge:
        aliases:
          - node1.emqx.local
    healthcheck:
      test: [ "CMD", "/opt/emqx/bin/emqx_ctl", "status" ]
      interval: 5s
      timeout: 25s
      retries: 5

networks:
  emqx-bridge:
    driver: bridge

volumes:
  emqx-data: { }
  emqx-log: { }
  emqx-etc: { }

EOL

      # Check if .env exists before creating
      if [ ! -f .env ]; then
        echo "CONFIG_PASSWORD=a" > .env
        echo "BOTS_PATH=$(pwd)" >> .env
      else
        echo ".env already exists, skipping creation."
      fi

      # Running docker-compose in detached mode
      docker compose -f docker-compose.dydx.yml pull
      docker compose -f docker-compose.dydx.yml up -d

      # Clear screen and show completion message
      clear
      echo "╔════════════════════════════════════════════════════════════╗"
      echo "║                 Installation (dYdX) Complete!              ║"
      echo "╚════════════════════════════════════════════════════════════╝"
      echo ""
      echo " You can now view Hummingbot Dashboard in your browser."
      echo ""
      echo " Network URL: http://localhost:8501"
      echo " Alternate URL: http://127.0.0.1:8501"
      echo ""
      echo " Backend API running on http://localhost:8000"
      echo " Swagger Docs: http://localhost:8000/docs"
      echo ""
      echo " For more documentation on how to use Dashboard "
      echo " https://hummingbot.org/dashboard"
      echo ""
      echo " To stop the running containers, run:"
      echo " docker compose -f docker-compose.dydx.yml down"
      echo ""
      exit 0
      ;;
    3)
      echo "Dashboard only mode..."
      # Create a permanent docker-compose file for dashboard
      cat > docker-compose.dashboard.yml << 'EOL'
services:
  dashboard:
    container_name: dashboard
    image: hummingbot/dashboard:latest
    ports:
      - "8501:8501"
    environment:
        - AUTH_SYSTEM_ENABLED=False
        - BACKEND_API_HOST=backend-api
        - BACKEND_API_PORT=8000
        - BACKEND_API_USERNAME=admin
        - BACKEND_API_PASSWORD=admin
    volumes:
      - ./credentials.yml:/home/dashboard/credentials.yml
      - ./pages:/home/dashboard/frontend/pages
    networks:
      - emqx-bridge

networks:
  emqx-bridge:
    driver: bridge
EOL

      # Use the dashboard compose file
      docker compose -f docker-compose.dashboard.yml pull
      docker compose -f docker-compose.dashboard.yml up -d

      # Clear screen and show completion message
      clear
      echo "╔════════════════════════════════════════════════════════════╗"
      echo "║                Dashboard Installation Complete             ║"
      echo "╚════════════════════════════════════════════════════════════╝"
      echo ""
      echo " You can now view Hummingbot Dashboard in your browser."
      echo ""
      echo " Network URL: http://localhost:8501"
      echo " Alternate URL: http://127.0.0.1:8501"
      echo ""
      echo " For more documentation on how to use Dashboard "
      echo " https://hummingbot.org/dashboard"
      echo ""
      echo " To stop the dashboard service, run:"
      echo " docker compose -f docker-compose.dashboard.yml down"
      echo ""
      exit 0
      ;;
    4)
      echo "Backend-API only mode..."
      # Create a permanent docker-compose file for backend-api
      cat > docker-compose.backend.yml << 'EOL'
services:
  backend-api:
    container_name: backend-api
    image: hummingbot/backend-api:latest
    ports:
      - "8000:8000"
    volumes:
      - ./bots:/backend-api/bots
      - /var/run/docker.sock:/var/run/docker.sock
    env_file:
      - .env
    environment:
      - BROKER_HOST=emqx
      - BROKER_PORT=1883
      - USERNAME=admin
      - PASSWORD=admin
    networks:
      - emqx-bridge

networks:
  emqx-bridge:
    driver: bridge
EOL

      # Check if .env exists before creating
      if [ ! -f .env ]; then
        echo "CONFIG_PASSWORD=a" > .env
        echo "BOTS_PATH=$(pwd)" >> .env
      else
        echo ".env already exists, skipping creation."
      fi

      # Use the backend compose file
      docker compose -f docker-compose.backend.yml pull
      docker compose -f docker-compose.backend.yml up -d

      # Clear screen and show completion message
      clear
      echo "╔════════════════════════════════════════════════════════════╗"
      echo "║              Backend API Installation Complete!            ║"
      echo "╚════════════════════════════════════════════════════════════╝"
      echo ""
      echo " Backend API running on http://localhost:8000"
      echo " Swagger Docs: http://localhost:8000/docs"
      echo ""
      echo " To stop the backend service, run:"
      echo " docker compose -f docker-compose.backend.yml down"
      echo ""
      exit 0
      ;;
    5)
      echo "Broker Only mode..."
      # Create a permanent docker-compose file for broker
      cat > docker-compose.broker.yml << 'EOL'
services:
  emqx:
    container_name: hummingbot-broker
    image: emqx:5
    restart: unless-stopped
    environment:
      - EMQX_NAME=emqx
      - EMQX_HOST=node1.emqx.local
      - EMQX_CLUSTER__DISCOVERY_STRATEGY=static
      - EMQX_CLUSTER__STATIC__SEEDS=[emqx@node1.emqx.local]
      - EMQX_LOADED_PLUGINS="emqx_recon,emqx_retainer,emqx_management,emqx_dashboard"
    volumes:
      - emqx-data:/opt/emqx/data
      - emqx-log:/opt/emqx/log
      - emqx-etc:/opt/emqx/etc
    ports:
      - "1883:1883"  # mqtt:tcp
      - "8883:8883"  # mqtt:tcp:ssl
      - "8083:8083"  # mqtt:ws
      - "8084:8084"  # mqtt:ws:ssl
      - "8081:8081"  # http:management
      - "18083:18083"  # http:dashboard
      - "61613:61613"  # web-stomp gateway
    networks:
      emqx-bridge:
        aliases:
          - node1.emqx.local
    healthcheck:
      test: [ "CMD", "/opt/emqx/bin/emqx_ctl", "status" ]
      interval: 5s
      timeout: 25s
      retries: 5

networks:
  emqx-bridge:
    driver: bridge

volumes:
  emqx-data: { }
  emqx-log: { }
  emqx-etc: { }
EOL

      # Use the broker compose file
      docker compose -f docker-compose.broker.yml pull
      docker compose -f docker-compose.broker.yml up -d

      # Clear screen and show completion message
      clear
      echo "╔════════════════════════════════════════════════════════════╗"
      echo "║                Broker Installation Complete                ║"
      echo "╚════════════════════════════════════════════════════════════╝"
      echo ""
      echo " Hummingbot Broker service is running in the background"
      echo ""
      echo " To stop the broker service, run:"
      echo " docker compose -f docker-compose.broker.yml down"
      echo ""
      exit 0
      ;;
    6)
      echo "Hummingbot Client Only mode..."
      # Create a permanent docker-compose file for Hummingbot client
      cat > docker-compose.client.yml << 'EOL'
services:
  hummingbot:
    container_name: hummingbot
    image: hummingbot/hummingbot:latest
    volumes:
      - ./conf:/home/hummingbot/conf
      - ./conf/connectors:/home/hummingbot/conf/connectors
      - ./conf/strategies:/home/hummingbot/conf/strategies
      - ./conf/controllers:/home/hummingbot/conf/controllers
      - ./conf/scripts:/home/hummingbot/conf/scripts
      - ./logs:/home/hummingbot/logs
      - ./data:/home/hummingbot/data
      - ./certs:/home/hummingbot/certs
      - ./scripts:/home/hummingbot/scripts
      - ./controllers:/home/hummingbot/controllers
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
    tty: true
    stdin_open: true
    network_mode: host
EOL

      # Use the client compose file
      docker compose -f docker-compose.client.yml pull
      docker compose -f docker-compose.client.yml up -d

      # Clear screen and show completion message
      clear
      echo "╔════════════════════════════════════════════════════════════╗"
      echo "║             Hummingbot Client Installation Complete        ║"
      echo "╚════════════════════════════════════════════════════════════╝"
      echo ""
      echo " Hummingbot is running in the background"
      echo ""
      echo " To connect to Hummingbot, run the command:"
      echo " docker attach hummingbot"
      echo ""
      echo " To stop the Hummingbot client, run:"
      echo " docker compose -f docker-compose.client.yml down"
      echo ""
      exit 0
      ;;
    7)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please try again."
      ;;
  esac
done






