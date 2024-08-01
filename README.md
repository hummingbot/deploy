# hummingbot-deploy

Welcome to the Hummingbot Deploy project. This guide will walk you through the steps to deploy multiple trading bots using a centralized dashboard and a service backend.

## Prerequisites

- Docker must be installed on your machine. If you do not have Docker installed, you can download and install it from [Docker's official site](https://www.docker.com/products/docker-desktop).
- If you are on Windows, you'll need to setup WSL2 and a Linux terminal like Ubuntu. Make sure to run the commands below in a Linux terminal and not in the Windows command prompt or Powershell.

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hummingbot/deploy.git
   cd deploy
   ```

## Running the Application

1. **Start and configure the Application**
   - Run the following command to download and start the app.
   - ```bash
     bash setup.sh
     ```
2. **Access the dashboard:**
   - Open your web browser and go to `localhost:8501`. Replace `localhost` with the IP of your server if using a cloud server.

3. **API Keys and Credentials:**
   - Go to the credentials page
   - You add credentials to the master account by picking the exchange and adding the API key and secret. This will encrypt the keys and store them in the master account folder.
   - If you are managing multiple accounts you can create a new one and start adding new credentials there.

4. **Create a config for PMM Simple**
   - Go to the tab PMM Simple and create a new configuration. Soon will be released a video explaining how the strategy works.

5. **Deploy the configuration**
   - Go to the Deploy tab, select a name for your bot, the image hummingbot/hummingbot:latest and the configuration you just created.
   - Press the button to create a new instance.

6. **Check the status of the bot**
   - Go to the Instances tab and check the status of the bot.
     - If it's not available is because the bot is starting, wait a few seconds and refresh the page.
     - If it's running, you can check the performance of it in the graph, refresh to see the latest data.
     - If it's stopped, probably the bot had an error, you can check the logs in the container to understand what happened.

7. **[Optional] Check the Backend API**
   -  Open your web browser and go to `localhost:8000/docs`.

## Authentication

Authentication is disabled by default. To enable Dashboard Authentication please follow the steps below: 

**Set Credentials (Optional):**

The dashboard uses `admin` and `abc` as the default username and password respectively. It's strongly recommended to change these credentials for enhanced security.:

- Navigate to the `deploy` folder and open the `credentials.yml` file.
- Add or modify the current username / password and save the changes afterward
  
  ```
  credentials:
    usernames:
      admin:
        email: admin@gmail.com
        name: John Doe
        logged_in: False
        password: abc
  cookie:
    expiry_days: 0
    key: some_signature_key # Must be string
    name: some_cookie_name
  pre-authorized:
    emails:
    - admin@admin.com
  ```  
### Enable Authentication

- Ensure the dashboard container is not running.
- Open the `docker-compose.yml` file within the `deploy` folder using a text editor.
- Locate the environment variable `AUTH_SYSTEM_ENABLED` under the dashboard service configuration.
  
  ```
  services:
  dashboard:
    container_name: dashboard
    image: hummingbot/dashboard:latest
    ports:
      - "8501:8501"
    environment:
        - AUTH_SYSTEM_ENABLED=True
        - BACKEND_API_HOST=backend-api
        - BACKEND_API_PORT=8000
  ```
- Change the value of `AUTH_SYSTEM_ENABLED` from `False` to `True`.
- Save the changes to the `docker-compose.yml` file.
- Relaunch Dashboard by running `bash setup.sh`
  
### Known Issues
- Refreshing the browser window may log you out and display the login screen again. This is a known issue that might be addressed in future updates.


## Dashboard Functionalities

- **Config Generator:**
  - Create and select configurations for different v2 strategies.
  - Backtest and deploy the selected configurations.

- **Bot Management:**
  - Visualize bot performance in real-time.
  - Stop and archive running bots.

## Tutorial

To get started with deploying your first bot, follow these step-by-step instructions:

1. **Prepare your bot configurations:**
   - Select a controller and backtest your controller configs.

2. **Deploy a bot:**
   - Use the dashboard UI to select and deploy your configurations.

3. **Monitor and Manage:**
   - Track bot performance and make adjustments as needed through the dashboard.
