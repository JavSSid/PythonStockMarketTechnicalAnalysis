# S&P 500 Stock Market Technical Analysis

End-to-end data engineering pipeline that processes S&P 500 stock data from raw ingestion through cleaning, enrichment, and aggregation, surfaced via an interactive dashboard.

## Architecture

```
bronze.stocks ──► silver.stocks ──► gold.daily_summary ──► Streamlit Dashboard
bronze.companies ──► silver.companies ──► gold.sector_performance
bronze.index ──► silver.index ──► gold.moving_crossovers
                                ──► gold.monthly_volatility
```

## Tech Stack

| Layer | Tool |
|-------|------|
| Database | PostgreSQL 18 |
| Transformations | Raw SQL |
| Backfill | Python (psycopg2) |
| Orchestration | Apache Airflow (Docker) |
| Dashboard | Streamlit + Plotly |

## Project Structure

```
├── dags/stock_pipeline.py              # Airflow DAG
├── sql/
│   ├── silver/                         # Cleaning & enrichment (3 files)
│   ├── gold/                           # Aggregation & KPIs (4 files)
│   ├── tests/quality_checks.sql        # Data validation
│   └── dashboards/metabase_queries.sql # Example SQL queries
├── scripts/backfill.py                 # One-time backfill
├── dashboard.py                        # Streamlit app
├── docker-compose.yml                  # Airflow + Metabase
└── requirements.txt
```

## Quick Start

```bash
pip install -r requirements.txt
python scripts/backfill.py     # run full pipeline
streamlit run dashboard.py     # launch dashboard at :8501
make airflow-up                # start Airflow (optional)
```

## Dashboard Views

- **Sector Overview** — daily returns by sector, cumulative trends, top/bottom performers
- **Symbol Deep Dive** — OHLC candlestick + 4 moving averages + volume + crossover signals
- **Volatility Monitor** — ranked monthly volatility vs return for all stocks

## Data

- 1.89M raw rows, ~618K after cleaning (172 of 502 S&P 500 symbols with price data)
- Date range: 2010-01-04 to 2024-12-20
- Gold layer includes: daily moving averages (7/21/50/200), sector aggregates, golden/death cross signals, monthly volatility rankings
