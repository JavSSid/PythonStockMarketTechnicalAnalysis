DROP TABLE IF EXISTS gold.sector_performance CASCADE;

CREATE TABLE gold.sector_performance (
    date                  DATE        NOT NULL,
    sector                VARCHAR(100) NOT NULL,
    num_companies         INTEGER,
    avg_daily_return      NUMERIC(10,6),
    median_daily_return   NUMERIC(10,6),
    total_volume          BIGINT,
    avg_market_cap        NUMERIC(20,2),
    top_gainer_symbol     VARCHAR(10),
    top_gainer_return     NUMERIC(10,6),
    top_loser_symbol      VARCHAR(10),
    top_loser_return      NUMERIC(10,6),
    ingested_at           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (date, sector)
);

WITH daily_sector AS (
    SELECT
        s.date,
        s.sector,
        s.symbol,
        s.daily_return,
        s.volume,
        c.market_cap,
        ROW_NUMBER() OVER (PARTITION BY s.date, s.sector ORDER BY s.daily_return DESC) AS rn_best,
        ROW_NUMBER() OVER (PARTITION BY s.date, s.sector ORDER BY s.daily_return ASC)  AS rn_worst
    FROM silver.stocks s
    LEFT JOIN silver.companies c ON c.symbol = s.symbol
    WHERE s.daily_return IS NOT NULL
)
INSERT INTO gold.sector_performance
SELECT
    date,
    sector,
    COUNT(*)                                                AS num_companies,
    ROUND(AVG(daily_return)::NUMERIC, 6)                    AS avg_daily_return,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY daily_return)::NUMERIC, 6)
                                                            AS median_daily_return,
    SUM(volume)                                             AS total_volume,
    AVG(market_cap)                                         AS avg_market_cap,
    MAX(symbol) FILTER (WHERE rn_best  = 1)                 AS top_gainer_symbol,
    MAX(daily_return) FILTER (WHERE rn_best  = 1)           AS top_gainer_return,
    MAX(symbol) FILTER (WHERE rn_worst = 1)                 AS top_loser_symbol,
    MAX(daily_return) FILTER (WHERE rn_worst = 1)           AS top_loser_return
FROM daily_sector
GROUP BY date, sector
ORDER BY date, sector;
