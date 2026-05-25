# End-to-End Stock Market Data Engineering Project

## Architecture (Implemented)

```
Bronze (PostgreSQL) ──► Silver (PostgreSQL) ──► Gold (PostgreSQL) ──► Dashboard
      │                       │                        │
   sp500_db               Cleaned data             Aggregated/KPIs
   raw CSVs               Enriched                 Business metrics
   ingested               Typed/validated          Ready for analytics
```

## Tech Stack (Actual)

| Layer | Tool | Purpose |
|-------|------|---------|
| **Database** | PostgreSQL 18 (local) | All layers — bronze, silver, gold |
| **Transformations** | Raw SQL | Layer-separated files in `sql/silver/` and `sql/gold/` |
| **Backfill** | Python (`psycopg2`) | `scripts/backfill.py` — runs all SQL files sequentially |
| **Orchestration** | Apache Airflow (Docker) | `dags/stock_pipeline.py` — PostgresOperator tasks |
| **Dashboard** | Streamlit + Plotly | `dashboard.py` — interactive web UI |
| **Infra** | Docker Compose | Airflow webserver + scheduler + Airflow metadata DB |

---

## Project Structure

```
stocks-analysis/
├── dags/
│   └── stock_pipeline.py              # Airflow DAG (bronze → silver → gold)
├── sql/
│   ├── setup/
│   │   └── create_schemas.sql         # silver + gold schemas
│   ├── silver/
│   │   ├── 01_clean_stocks.sql        # Cast, filter nulls, enrich with returns/range
│   │   ├── 02_clean_index.sql         # Cast dates, compute lag-based returns
│   │   └── 03_clean_companies.sql     # Cast types, rename columns
│   ├── gold/
│   │   ├── 01_daily_summary.sql       # Moving averages (7/21/50/200) + rolling vol
│   │   ├── 02_sector_performance.sql  # Per-sector daily aggregates
│   │   ├── 03_moving_crossovers.sql   # Golden/death cross signals
│   │   └── 04_monthly_volatility_rank.sql  # Monthly volatility rankings
│   ├── tests/
│   │   └── quality_checks.sql         # Data quality validation queries
│   └── dashboards/
│       └── metabase_queries.sql       # Example SQL for Metabase
├── scripts/
│   └── backfill.py                    # One-time full backfill runner
├── config/
│   └── .env.example
├── dashboard.py                       # Streamlit dashboard (3 views)
├── docker-compose.yml                 # Airflow + Metabase + metadata DB
├── Makefile
├── requirements.txt
├── stock-data-engineering-plan.md
└── .gitignore
```

---

## Bronze Layer (Raw)

**Database:** `sp500_db` (PostgreSQL), user: `postgres`

### Tables

#### `bronze.stocks`
- 1,891,536 rows, 502 symbols, 2010-01-04 to 2024-12-20
- Columns: `Date` (text), `Symbol` (text), `Adj Close`, `Close`, `High`, `Low`, `Open`, `Volume` (double precision)
- 172 of 502 symbols have actual price data (617,831 filled rows)
- Nulls for remaining 330 symbols — filtered out during Silver transform

#### `bronze.companies`
- 502 rows (one per S&P 500 company)
- Columns: `Exchange`, `Symbol`, `Shortname`, `Longname`, `Sector`, `Industry`, `Currentprice`, `Marketcap`, `Ebitda`, `Revenuegrowth`, `City`, `State`, `Country`, `Fulltimeemployees`, `Weight`

#### `bronze.index`
- 2,517 rows, S&P 500 daily index, 2014-12-22 to 2024-12-20
- Columns: `Date` (text), `S&P500` (double precision)

### Key Quality Issues Found
- Column names with spaces (`"Adj Close"`, `"Date"`, etc.)
- `Date` stored as text, not `DATE`
- `Volume` stored as double precision, not `BIGINT`
- 66% of rows have NULL prices (symbols with no data)

---

## Silver Layer — Cleaning & Enrichment

### Transformations in `01_clean_stocks.sql`

| Step | Detail |
|------|--------|
| **Type casting** | `"Date"` → `DATE`, `"Volume"` → `BIGINT` |
| **Null filter** | `WHERE "Close" IS NOT NULL` — drops 1.27M rows |
| **Column rename** | Space-separated → snake_case (`"Adj Close"` → `adj_close`) |
| **Enrichment** | Join `bronze.companies` on `Symbol` to add `sector`, `industry`, `market_cap`, `company_name` |
| **Computed columns** | `daily_return = (close - open) / open`, `daily_range = (high - low) / close` |

### Transformations in `02_clean_index.sql`
- Cast `"Date"` → `DATE`, `"S&P500"` → `NUMERIC(12,2)`
- Compute `daily_return` using `LAG()` for day-over-day index return

### Transformations in `03_clean_companies.sql`
- Cast types (`Fulltimeemployees` → `INTEGER`, prices → `NUMERIC`)
- Rename columns to snake_case

### Output: `silver.stocks`
- 617,831 rows — deduplicated, typed, enriched with company metadata
- Primary key: `(symbol, date)`

---

## Gold Layer — Aggregation & Business Metrics

### `gold.daily_summary` (617,831 rows)
- Moving averages via window functions: `MA_7`, `MA_21`, `MA_50`, `MA_200`
- 21-day rolling volatility: `STDDEV(daily_return)` over 21-day window

### `gold.sector_performance` (41,448 rows)
- Per-sector, per-date aggregates: avg/median return, total volume, top gainer & loser
- Uses `ROW_NUMBER()` + `FILTER` to identify best/worst performers

### `gold.moving_crossovers` (617,831 rows)
- Golden cross: `MA_7` crosses above `MA_21` (or `MA_21` above `MA_50`)
- Death cross: `MA_7` crosses below `MA_21` (or `MA_21` below `MA_50`)
- Signal logic: compare current vs previous window-order MA values

### `gold.monthly_volatility` (29,525 rows)
- Monthly rollup: avg daily range, avg rolling volatility, compound total return
- Compound return: `EXP(SUM(LN(1 + daily_return))) - 1`
- Ranked by volatility within each month

---

## Orchestration

### One-time Backfill (`make setup` / `python scripts/backfill.py`)
- Runs all `.sql` files in order: `setup/` → `silver/` → `gold/`
- Uses `psycopg2` directly — no ORM, no dbt
- Each file is a `DROP TABLE IF EXISTS ... CASCADE` + `CREATE TABLE` + `INSERT`

### Scheduled Runs (Airflow DAG)
- `dags/stock_pipeline.py` uses `PostgresOperator` to execute the same SQL
- DAG schedule: daily at 6 AM
- Dependency order:
  ```
  create_schemas
      ├── clean_stocks
      ├── clean_index
      └── clean_companies
              └── daily_summary
                      ├── sector_performance
                      ├── moving_crossovers
                      └── monthly_volatility_rank
  ```
- Requires Airflow connection `stock_db` pointing to local PostgreSQL

---

## Dashboard

### Streamlit (`dashboard.py`)

Runs locally at `http://localhost:8501`. Three views:

| View | Controls | What it shows |
|------|----------|---------------|
| **Sector Overview** | Sector dropdown | Bar chart of avg daily return by sector, cumulative return line chart, stock list for selected sector |
| **Symbol Deep Dive** | Symbol dropdown | Interactive OHLC candlestick + 4 MAs + volume bars + crossover signals |
| **Volatility Monitor** | Sector dropdown | Top 20 volatile stocks bar chart, volatility-vs-return scatter |

Python libraries: `streamlit`, `pandas`, `plotly`, `psycopg2-binary`

---

## Data Quality

Tests in `sql/tests/quality_checks.sql`:

| Check | Result |
|-------|--------|
| Row count parity (bronze → silver → gold) | 617,831 consistent across cleaned layers |
| Null symbols or dates | 0 failures |
| Duplicate primary keys | 0 failures |
| Daily return > 100% | 0 failures |
| Date range | 2010-01-04 to 2024-12-20 |

---

## Quick Start

```bash
pip install -r requirements.txt
make setup                  # one-time backfill
make airflow-up             # docker compose up for Airflow
streamlit run dashboard.py  # launch dashboard
```

---

## Commands Reference

| Command | Action |
|---------|--------|
| `make setup` | Run full backfill (setup → silver → gold) |
| `make airflow-up` | Start Airflow + Metabase via Docker Compose |
| `make airflow-down` | Stop Docker Compose services |
| `streamlit run dashboard.py` | Launch Streamlit dashboard on :8501 |
| `python scripts/backfill.py` | Re-run all SQL transforms |

---

## File Inventory

| File | Lines | Purpose |
|------|-------|---------|
| `sql/setup/create_schemas.sql` | 2 | Create silver and gold schemas |
| `sql/silver/01_clean_stocks.sql` | 47 | Bronze stocks → silver stocks |
| `sql/silver/02_clean_index.sql` | 21 | Bronze index → silver index |
| `sql/silver/03_clean_companies.sql` | 24 | Bronze companies → silver companies |
| `sql/gold/01_daily_summary.sql` | 42 | Silver → daily summary + MAs |
| `sql/gold/02_sector_performance.sql` | 49 | Silver → sector daily aggregates |
| `sql/gold/03_moving_crossovers.sql` | 37 | Daily summary → crossover signals |
| `sql/gold/04_monthly_volatility_rank.sql` | 36 | Daily summary → monthly volatility ranks |
| `sql/tests/quality_checks.sql` | 39 | Data quality validation |
| `dags/stock_pipeline.py` | 57 | Airflow DAG definition |
| `scripts/backfill.py` | 51 | One-time backfill runner |
| `dashboard.py` | ~160 | Streamlit dashboard |
| `docker-compose.yml` | 52 | Airflow + Metabase services |
