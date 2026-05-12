# Condor Deploy

This folder helps you install **Condor** (a Telegram bot for trading) and, if you want, **Hummingbot API** (a web service on your computer). You do **not** need to be a programmer: copy one of the commands below, paste it into **Terminal**, press **Enter**, and answer any questions the installer asks.

---

## What you need

- A **Mac** or **Linux** computer (Windows users: install **WSL2** with Ubuntu, then use Terminal inside Ubuntu).
- The **Terminal** app open.
- A **stable internet** connection.
- For **Hummingbot API only** (the second command below): **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** (Mac/Windows) or Docker on Linux, **installed and running** before you run the command.

---

## Install Condor (start here)

Open Terminal, go to an **empty folder** where you are happy to create files (for example your home folder, or `cd Desktop` first), then paste:

```bash
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash
```

The script will guide you (for example **Telegram** bot token and your user id). When it finishes, continue to **After installation** below.

---

## Install only Hummingbot API

Use this if you **only** want the API and database on this machine (Docker must already be running):

```bash
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash -s -- --hummingbot-api
```

---

## Update to the latest version

Go back to the **same folder** where you first ran the installer (where the `condor` folder lives), then paste:

```bash
curl -fsSL https://raw.githubusercontent.com/hummingbot/deploy/refs/heads/main/setup.sh | bash -s -- --upgrade
```

---

## After installation

### 1. Check Telegram

Open Telegram and your **Condor bot** chat. If the bot started correctly, you should see a message like:

> **Condor is online and ready.**

If you **do not** see that after a minute or two, use the next step to read error messages.

### 2. Read the bot’s log (if something looks wrong)

Paste this, then press **Enter**:

```bash
tmux attach -t condor
```

You will see text scrolling by—that is the bot’s log. To **close the log but keep the bot running**: press **Ctrl+B**, let go, then press **D**.

### 3. Open the API in the browser (only if you installed the API)

On the same computer, open:

[http://localhost:8000/docs](http://localhost:8000/docs)

---

## If something goes wrong

- **“Docker” errors** — Start Docker Desktop (or your Linux Docker service), wait until it is fully running, then run the command again.
- **Telegram bot silent** — Open the log (`tmux attach -t condor`) and check that the token and admin id you entered are correct.
- **Still stuck** — Ask on **[Discord](https://discord.hummingbot.io)** or open an issue on **[GitHub](https://github.com/hummingbot/deploy/issues)**.

---

## If the one-line install does not work (manual backup)

Only try this if the `curl` command fails or your network blocks the download. You need more technical comfort here.

**Condor** — clone [the Condor repository](https://github.com/hummingbot/condor), then in that folder run `make install` and start the app with `make run` .

**Hummingbot API (Docker):**

```bash
git clone --depth 1 https://github.com/hummingbot/hummingbot-api.git hummingbot-api
cd hummingbot-api && make setup && docker compose pull && make deploy
```

---

## If you already downloaded this folder from GitHub

Use the same commands, but start with `bash` instead of `curl`:

```bash
bash setup.sh
bash setup.sh --hummingbot-api
bash setup.sh --upgrade
```

---

## More help

- **Documentation:** [Hummingbot Docs](https://docs.hummingbot.org)  
- **Discord:** [Hummingbot Discord](https://discord.hummingbot.io)  
- **Problems with this installer:** [GitHub — hummingbot/deploy](https://github.com/hummingbot/deploy/issues)

---

## License

Hummingbot Deploy is licensed under the **HUMMINGBOT OPEN SOURCE LICENSE AGREEMENT**. See the **LICENSE** file in this repository for details.
