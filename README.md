# Geodeterminants App

A browser-based tool for enriching a list of addresses with Social Determinants of Health (SDOH) data. Type in your addresses, click Analyze, download your results — no programming required.

Built on the [geodeterminants](https://github.com/wchan05/geodeterminants) R package by Wesley Chan.

---

## For the PI / end user

Someone (likely the person who sent you this link) has already set up the app. Just open the link in any browser, type or paste your addresses, and click **Analyze Addresses**.

**You do not need to install anything.**

---

## Deploying (one-time setup, done by a developer)

Two options — both result in a URL you can share with anyone. Neither requires the PI to install anything.

### Option A — Render.com (recommended)

Render.com builds and runs the app using Docker. **Your PI never sees or interacts with Docker** — they just open a URL in their browser. Docker is internal to Render's infrastructure.

This app uses geospatial R packages (sf, tigris) that require specific system libraries. Docker guarantees those libraries are present at the exact right version; this is the most reliable path.

**Click to deploy:**

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/iddoresh/geodeterminants-app)

That button opens Render's service wizard with this repo pre-filled. You will need:

1. A Render.com account (free to create at [render.com](https://render.com))
2. A Census API key — get one free at [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html) (enter your name and email, key arrives by email in minutes)
3. When the wizard asks for `CENSUS_API_KEY`, paste your key

The first build takes 10–15 minutes (R packages compile). When it finishes, Render gives you a URL like `https://geodeterminants-app.onrender.com`. Share that with your PI — they open it in any browser, done.

> **Note on the free tier:** Render discontinued free web services in late 2023. The Starter plan is $7/month and keeps the app always-on. If you want zero cost, use the shinyapps.io option below.

---

### Option B — shinyapps.io (no Docker, but geospatial packages may not work)

shinyapps.io is Posit's free hosting service for R Shiny apps. No Docker required. However, this app uses geospatial packages (sf, tigris) that depend on system libraries, and shinyapps.io uses a pinned Ubuntu image — version mismatches are common. **Try this if you want, but use Render.com if you hit build errors.**

**Prerequisites on your machine:** R installed, plus the `rsconnect` package.

```r
install.packages("rsconnect")
```

**Step 1** — Create a free account at [shinyapps.io](https://www.shinyapps.io) and copy your token from Account → Tokens.

**Step 2** — Connect your account in R:

```r
rsconnect::setAccountInfo(
  name   = "your-shinyapps-username",
  token  = "YOUR_TOKEN",
  secret = "YOUR_SECRET"
)
```

**Step 3** — Get a free Census API key at [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html).

**Step 4** — Deploy from the repo root:

```r
rsconnect::deployApp(
  appDir  = "shiny/",
  appName = "geodeterminants"
)
```

**Step 5** — In the shinyapps.io dashboard, go to your app → Settings → Environment Variables, add `CENSUS_API_KEY` with your key. The app redeploys. Share the URL (e.g. `https://your-username.shinyapps.io/geodeterminants`) with your PI.

> **Free tier:** 25 active hours/month — plenty for lab use at ~5 min per run.

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

Your CSV must have at minimum an address column. The tool auto-detects column names, or you can map them manually.

| Column | Required | Notes |
|--------|----------|-------|
| `address` | Yes | Full street address (e.g. "15 Main St, Flemington, NJ 08822") |
| `state` | Recommended | 2-letter abbreviation (NJ, CA, TX). Improves geocoding accuracy. |
| `year` | Recommended | Year of the data (e.g. 2023). Defaults to current year - 2 if not provided. |

Download a sample CSV from the app interface to see the expected format.

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
|  4. Census API key (hidden when hosted)  |                                     |
|  [********************]                  |                                     |
|                                          |                                     |
|  [  Analyze Addresses  ]                 |                                     |
+------------------------------------------+-------------------------------------+
```

---

## Local install (for data privacy)

If addresses must never leave your machine (patient data, IRB restrictions), you can run the app locally. This requires Docker Desktop — a free GUI app.

**Prerequisites:** [Docker Desktop](https://docs.docker.com/desktop/) installed on your computer.

**Step 1** — Get a free Census API key at [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html).

**Step 2** — Open a Terminal (Mac/Linux) or Command Prompt (Windows), navigate to this folder, and run:

```bash
./install.sh
```

The first run downloads all dependencies (~10 minutes). After that, subsequent starts take about 10 seconds.

**Step 3** — Your browser will open to `http://localhost:3838`. Paste your Census API key when prompted, enter your addresses, and click Analyze.

To stop the app:
```bash
docker compose down
```

To restart later (fast, no rebuild):
```bash
docker compose up -d
```

---

## Troubleshooting

**App loads but analysis fails** — Check that your Census API key is entered correctly. Keys are activated within a few hours of signup.

**Some addresses could not be geocoded** — Verify each address includes a city and state. Example: `15 Main Street, Flemington, NJ 08822`.

**shinyapps.io: "package not available"** — Run `rsconnect::deployApp()` again; the first deploy sometimes fails on geospatial packages. If it consistently fails, use the Render.com path instead.

**Docker not running (local install)** — Open Docker Desktop from your Applications folder and wait for the icon to appear in the menu bar.

**Render.com first deploy takes 15 minutes** — Normal; R packages compile from source on first build. Subsequent deploys are faster.
