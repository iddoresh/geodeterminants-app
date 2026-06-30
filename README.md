# Geodeterminants App

A browser-based tool for enriching a list of addresses with Social Determinants of Health (SDOH) data. Upload a CSV, click Analyze, download your results — no programming required.

Built on the [geodeterminants](https://github.com/wchan05/geodeterminants) R package by Wesley Chan.

---

## Using the hosted app

If someone has already deployed this for you, just open the URL they shared. No installation needed — type or paste your addresses, fill in the settings, and click Analyze.

---

## Deploying your own instance (one-time setup, ~10 minutes)

The easiest way to host this yourself is **Render.com** — free tier, auto-deploys from GitHub.

**Step 1** — Create a free account at [render.com](https://render.com) and connect your GitHub account.

**Step 2** — Click **New → Web Service**, select the `geodeterminants-app` repository, and click **Create Web Service**. Render detects the Dockerfile automatically.

**Step 3** — In the service settings under **Environment**, add one variable:
- Key: `CENSUS_API_KEY`
- Value: your Census API key (get one free at [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html))

Click **Save Changes** — the app redeploys with the key configured. Your URL (`https://geodeterminants-app.onrender.com` or similar) is now live and shareable.

> **Note on free tier:** The app sleeps after 15 minutes of inactivity. The first visit after sleeping takes about 30 seconds to wake up. Upgrade to Render's Starter plan ($7/month) to keep it always-on.

---

## What you get

For each address, the tool appends:

| Module | Source |
|--------|--------|
| Air Quality Index | EPA Air Quality System |
| Concentrated Poverty | US Census ACS |
| Education Attainment | US Census ACS |
| Environmental Justice Index | EPA EJSCREEN |
| Retail Food Environment Index (Food Swamp) | USDA Food Environment Atlas |
| Income Concentration at Extremes (ICE) | US Census ACS |
| Minimum Wage | State wage databases |
| Percent Unionized Workforce | BLS |
| Race/Ethnic Dissimilarity Index | US Census ACS |
| Race/Ethnic Separation Index | US Census ACS |
| Decennial Dissimilarity Index | US Census Decennial |
| Social Vulnerability Index | CDC/ATSDR |

---

## Quick Install

**Prerequisites:** [Docker Desktop](https://docs.docker.com/desktop/) must be installed on your computer. It is free and takes about 5 minutes to install — just download and double-click the installer.

**Step 1 — Get a free Census API key**

Go to [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html), enter your name and email, and copy the key from the confirmation email. You only need to do this once.

**Step 2 — Start the app**

Open a Terminal (Mac/Linux) or Command Prompt (Windows), navigate to this folder, and run:

```bash
./install.sh
```

The first run downloads all dependencies (~5-10 minutes). After that, subsequent starts take about 10 seconds.

**Step 3 — Use the app**

Your browser will open to `http://localhost:3838`. Paste your Census API key, enter your addresses (type/paste or upload a CSV), and click Analyze.

---

## Input format

**Option A — Type or paste (easiest)**

In the app, select "Type or paste" and enter one address per line:

```
15 Main Street, Flemington, NJ 08822
401 W 14th St, Austin, TX 78701
1600 Pennsylvania Ave NW, Washington, DC 20500
```

Include city and state in each line for best geocoding results.

**Option B — Upload a CSV**

Your CSV must have at minimum an address column. The tool auto-detects column names, or you can map them manually in the interface.

| Column | Required | Notes |
|--------|----------|-------|
| `address` | Yes | Full street address (e.g. "15 Main St, Flemington, NJ 08822") |
| `state` | Recommended | 2-letter abbreviation (NJ, CA, TX). Improves geocoding accuracy. |
| `year` | Recommended | Year of the data (e.g. 2023). Defaults to current year - 2 if not provided. |

Download a [sample CSV](shiny/sample_addresses.csv) from the app interface to see the expected format.

---

## Stopping and restarting

To stop the app:
```bash
docker compose down
```

To restart it later (fast, no rebuild):
```bash
docker compose up -d
```

---

## Interface

```
+------------------------------------------+-------------------------------------+
|  Geodeterminants                         |                                     |
|  Social Determinants of Health           |  Social Determinants of Health      |
|                                          |  Enrichment                         |
|  1. Enter addresses                      |                                     |
|  ( ) Type or paste   ( ) Upload CSV      |  Two ways to provide addresses:     |
|                                          |  - Type or paste: one per line      |
|  [15 Main St, Flemington, NJ 08822    ]  |  - Upload CSV: spreadsheet format   |
|  [401 W 14th St, Austin, TX 78701     ]  |                                     |
|  [                                    ]  |  What you get back (12 modules):    |
|                                          |  - Air Quality Index                |
|  2. Population group of interest         |  - Concentrated Poverty             |
|  Group:    [Black or Afr. American v]    |  - Education Attainment             |
|  Compare:  [White alone (non-Hisp) v]    |  - ... (12 total)                   |
|                                          |                                     |
|  3. Parameters                           |                                     |
|  Year:  [2024]   Min wage: [$7.25]       |                                     |
|                                          |                                     |
|  4. Census API key                       |                                     |
|  [********************]                  |                                     |
|  [x] Remember key                        |                                     |
|                                          |                                     |
|  [  Analyze Addresses  ]                 |                                     |
+------------------------------------------+-------------------------------------+
```

---

## Troubleshooting

**"Docker is not running"** — Open Docker Desktop from your Applications folder and wait for the whale icon to appear in the menu bar.

**"Census API key not recognized"** — Check that you copied the full key from the email. Keys are activated within a few hours of signup.

**"Some addresses could not be geocoded"** — Verify your addresses include a city and state. The tool uses the Nominatim geocoder which requires reasonably complete addresses.

**App won't start after first install** — Run `docker compose logs` in the project folder to see error details.

---

## Sharing with others

Anyone with Docker Desktop can run this app:

1. Fork or clone this repository from GitHub
2. Run `./install.sh`
3. Enter their Census API key on first use

The key is stored locally on their machine and never leaves it.
