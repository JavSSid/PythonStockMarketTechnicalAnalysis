DROP TABLE IF EXISTS gold.moving_crossovers CASCADE;

CREATE TABLE gold.moving_crossovers (
    symbol       VARCHAR(10) NOT NULL,
    date         DATE        NOT NULL,
    company_name VARCHAR(255),
    sector       VARCHAR(100),
    close        NUMERIC(12,4),
    ma_7         NUMERIC(12,4),
    ma_21        NUMERIC(12,4),
    ma_50        NUMERIC(12,4),
    crossover_7_21  VARCHAR(20),
    crossover_21_50 VARCHAR(20),
    ingested_at     TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (symbol, date)
);

INSERT INTO gold.moving_crossovers
SELECT
    symbol,
    date,
    company_name,
    sector,
    close,
    ma_7,
    ma_21,
    ma_50,
    CASE
        WHEN LAG(ma_7)  OVER (PARTITION BY symbol ORDER BY date) < LAG(ma_21) OVER (PARTITION BY symbol ORDER BY date)
         AND ma_7 > ma_21 THEN 'GOLDEN_CROSS'
        WHEN LAG(ma_7)  OVER (PARTITION BY symbol ORDER BY date) > LAG(ma_21) OVER (PARTITION BY symbol ORDER BY date)
         AND ma_7 < ma_21 THEN 'DEATH_CROSS'
        ELSE NULL
    END AS crossover_7_21,
    CASE
        WHEN LAG(ma_21) OVER (PARTITION BY symbol ORDER BY date) < LAG(ma_50) OVER (PARTITION BY symbol ORDER BY date)
         AND ma_21 > ma_50 THEN 'GOLDEN_CROSS'
        WHEN LAG(ma_21) OVER (PARTITION BY symbol ORDER BY date) > LAG(ma_50) OVER (PARTITION BY symbol ORDER BY date)
         AND ma_21 < ma_50 THEN 'DEATH_CROSS'
        ELSE NULL
    END AS crossover_21_50
FROM gold.daily_summary;
