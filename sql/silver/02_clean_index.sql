DROP TABLE IF EXISTS silver.index CASCADE;

CREATE TABLE silver.index (
    date         DATE  NOT NULL PRIMARY KEY,
    sp500        NUMERIC(12,2),
    daily_return NUMERIC(10,6),
    ingested_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO silver.index (date, sp500, daily_return)
SELECT
    i."Date"::DATE,
    i."S&P500",
    CASE
        WHEN LAG(i."S&P500") OVER (ORDER BY i."Date"::DATE) IS NOT NULL
         AND i."S&P500" IS NOT NULL
         AND LAG(i."S&P500") OVER (ORDER BY i."Date"::DATE) <> 0
        THEN ROUND((
            (i."S&P500" - LAG(i."S&P500") OVER (ORDER BY i."Date"::DATE))
            / LAG(i."S&P500") OVER (ORDER BY i."Date"::DATE)
        )::NUMERIC, 6)
    END
FROM bronze.index i
WHERE i."S&P500" IS NOT NULL
ORDER BY i."Date"::DATE;
