DROP TABLE IF EXISTS gold.monthly_volatility CASCADE;

CREATE TABLE gold.monthly_volatility (
    year_month     DATE        NOT NULL,
    symbol         VARCHAR(10) NOT NULL,
    company_name   VARCHAR(255),
    sector         VARCHAR(100),
    avg_daily_range NUMERIC(10,6),
    avg_volatility  NUMERIC(10,6),
    total_return    NUMERIC(10,6),
    avg_volume      BIGINT,
    rank_by_range   INTEGER,
    rank_by_vol     INTEGER,
    ingested_at     TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (year_month, symbol)
);

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', date)::DATE AS year_month,
        symbol,
        company_name,
        sector,
        ROUND(AVG(daily_range)::NUMERIC, 6)       AS avg_daily_range,
        ROUND(AVG(volatility_21)::NUMERIC, 6)     AS avg_volatility,
        ROUND((EXP(SUM(LN(1 + daily_return))) - 1)::NUMERIC, 6) AS total_return,
        AVG(volume)::BIGINT              AS avg_volume
    FROM gold.daily_summary
    WHERE daily_return IS NOT NULL AND daily_range IS NOT NULL
    GROUP BY DATE_TRUNC('month', date), symbol, company_name, sector
)
INSERT INTO gold.monthly_volatility
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY year_month ORDER BY avg_daily_range DESC) AS rank_by_range,
    ROW_NUMBER() OVER (PARTITION BY year_month ORDER BY avg_volatility DESC)  AS rank_by_vol
FROM monthly;
