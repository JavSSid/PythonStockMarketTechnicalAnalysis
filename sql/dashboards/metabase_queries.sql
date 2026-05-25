-- ============================================================
-- Dashboard Queries — run these in Metabase SQL mode
-- Connect Metabase to your sp500_db PostgreSQL database
-- ============================================================

-- 1. Market Overview: sector returns heatmap
SELECT
  date,
  sector,
  avg_daily_return,
  num_companies,
  total_volume,
  top_gainer_symbol,
  top_gainer_return,
  top_loser_symbol,
  top_loser_return
FROM gold.sector_performance
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date DESC, avg_daily_return DESC;

-- 2. Symbol Deep Dive: candlestick + moving averages
SELECT
  date,
  open,
  high,
  low,
  close,
  volume,
  ma_7,
  ma_21,
  ma_50,
  ma_200,
  daily_return,
  daily_range
FROM gold.daily_summary
WHERE symbol = '{{symbol}}'
  AND date >= '{{start_date}}'
ORDER BY date;

-- 3. Volatility Monitor: top 20 most volatile stocks this month
SELECT
  ym.year_month,
  ym.symbol,
  ym.company_name,
  ym.sector,
  ym.avg_daily_range,
  ym.avg_volatility,
  ym.total_return,
  ym.rank_by_vol
FROM gold.monthly_volatility ym
WHERE ym.year_month = DATE_TRUNC('month', CURRENT_DATE)::DATE
ORDER BY ym.rank_by_vol ASC
LIMIT 20;

-- 4. Golden/Death Cross Signals: last 7 days
SELECT
  symbol,
  date,
  close,
  ma_7,
  ma_21,
  crossover_7_21
FROM gold.moving_crossovers
WHERE crossover_7_21 IS NOT NULL
  AND date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC, symbol;

-- 5. Best & Worst Performers Today
SELECT
  date,
  sector,
  top_gainer_symbol,
  top_gainer_return,
  top_loser_symbol,
  top_loser_return
FROM gold.sector_performance
WHERE date = (SELECT MAX(date) FROM gold.sector_performance)
ORDER BY avg_daily_return DESC;

-- 6. Cumulative sector return over time
SELECT
  date,
  sector,
  SUM(avg_daily_return) OVER (
    PARTITION BY sector ORDER BY date
  ) AS cumulative_return
FROM gold.sector_performance
WHERE date >= '2024-01-01'
ORDER BY date, sector;
