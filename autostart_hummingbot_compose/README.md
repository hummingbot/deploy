# Deploy and autostart a single Hummingbot instance with docker Compose

# How to use it

1. Ensure that you have Docker and Docker Compose installed on your machine.
2. To autostart, you will need the `config_file` of the strategy and the password already generated.
3. **Important:**
   - In this example, the password generated is `a`, and it was done on a Mac. If you are using a different OS or want to use a different password, make sure to delete the `.password_verification` file under the `conf` folder and follow the instructions in the troubleshooting section.
   - You can autostart a strategy or a script. In this case, on line `13`, we are autostarting a script that is inside the `scripts` folder. If you want to start a strategy, there is one `config` file under `conf/strategies`. You can change `format_status.py` for `conf_pure_mm_1.yml` to test it!
4. Make sure that the compose file on lines `12` and `13` have the correct path to the config file and the password.
5. Run the following command:
    ```
    docker-compose up -d
    ```
6. Attach the terminal:
    ```
    docker attach simple_hummingbot_compose-bot-1
    ```
7. Now you have Hummingbot running and autostarted! Remember that you can detach the terminal without stopping the bot by pressing `Ctrl + P` and `Ctrl + Q`.

## Troubleshooting
If you don't have the password, you can:
1. Remove lines `12` and `13` from the compose file.
2. Start the bot with the following command:
    ```
    docker-compose up -d
    ```
3. Attach the terminal:
    ```
    docker attach autostart_hummingbot_compose-bot-1
    ```
4. Create the password and exit the client.
5. Add lines `12` and `13` to the compose file and start over!
