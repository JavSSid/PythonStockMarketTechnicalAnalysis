-- ============================================================
-- Data Quality Checks for Stock Pipeline
-- Run with: psql -U postgres -d sp500_db -f sql/tests/quality_checks.sql
-- ============================================================

-- Check 1: Row counts across layers
SELECT 'bronze.stocks' AS layer, COUNT(*) AS rows, COUNT("Close") AS filled FROM bronze.stocks
UNION ALL
SELECT 'silver.stocks', COUNT(*), COUNT(close) FROM silver.stocks
UNION ALL
SELECT 'gold.daily_summary', COUNT(*), COUNT(close) FROM gold.daily_summary;

-- Check 2: No null symbols or dates
SELECT 'silver null symbols' AS check_name, COUNT(*) AS failures FROM silver.stocks WHERE symbol IS NULL OR date IS NULL
UNION ALL
SELECT 'gold null symbols', COUNT(*) FROM gold.daily_summary WHERE symbol IS NULL OR date IS NULL;

-- Check 3: Duplicate primary keys
SELECT 'silver dupes' AS check_name, COUNT(*) AS failures FROM (
    SELECT symbol, date, COUNT(*) FROM silver.stocks GROUP BY symbol, date HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'gold dupes', COUNT(*) FROM (
    SELECT symbol, date, COUNT(*) FROM gold.daily_summary GROUP BY symbol, date HAVING COUNT(*) > 1
) d;

-- Check 4: Daily return sanity (|return| < 100%)
SELECT 'daily_return > 100%' AS check_name, COUNT(*) AS failures
FROM gold.daily_summary WHERE ABS(daily_return) > 1;

-- Check 5: Date range per layer
SELECT 'silver date range' AS label, MIN(date) AS start, MAX(date) AS end FROM silver.stocks
UNION ALL
SELECT 'gold date range', MIN(date), MAX(date) FROM gold.daily_summary;

-- Check 6: Sector coverage
SELECT sector, COUNT(DISTINCT symbol) AS companies FROM gold.daily_summary GROUP BY sector ORDER BY companies DESC;
