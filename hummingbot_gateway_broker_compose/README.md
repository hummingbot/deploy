# Deploy: Hummingbot + Gateway (DEX Connectors) + EMQX Message Broker (MQTT feature)

This docker compose deployment includes Gateway and EMQX broker. Though it is 
recommended to use the standalone deployments for message brokers from the [hummingbot/brokers](https://github.com/hummingbot/brokers) 
repository.

After deploying for the first time, you can navigate to the EMQX dashboard
to configure authentication and available ports at http://localhost:18083/.
The default credentials for connecting to the dashboards are `admin:public`.
For connecting your bots via MQTT, just leave the `mqtt_username` and
`mqtt_password` parameters of the bot empty.

## How to use it

You will need to have the certificates for the gateway and hummingbot under the folder hummingbot_files/certs. If you don't have it, don't worry, you can generate them with the client by doing the following:

- Make sure you have docker and docker-compose installed.
- Run the following command in the terminal:

    ```
    docker-compose up -d
    ```

- You will see that the gateway failed to start because you don't have the certificates
- Attach the instance of the bot by running:

    ```
    docker attach hummingbot_gateway_compose-bot-1
    ```

- Create the password
- Run the following command in the client:

    ```
    gateway generate-certs
    ```

- When prompted enter the passphrase that you want. Is important that you change the docker-compose.yml on line 18 to the passphrase that you entered (the current passphrase is `a`).
- Exit the client and run the following command in the terminal:

    ```
    docker-compose down
    ```

- You will see that inside the hummingbot_files/certs folder you have the certificates.
- We are ready to deploy the gateway and hummingbot, run the following command in the terminal:

    ```
    docker-compose up -d
    ```

- If you attach the terminal of the gateway you will see that it is running.

    ```
    docker attach hummingbot_gateway_compose-gateway-1
    ```

- If you attach the terminal of the bot you will see that it is running and the gateway is ONLINE.

    ```
    docker attach hummingbot_gateway_compose-bot-1
    ```
