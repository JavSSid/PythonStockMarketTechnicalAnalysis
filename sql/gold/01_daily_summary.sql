DROP TABLE IF EXISTS gold.daily_summary CASCADE;

CREATE TABLE gold.daily_summary (
    symbol       VARCHAR(10) NOT NULL,
    date         DATE        NOT NULL,
    company_name VARCHAR(255),
    sector       VARCHAR(100),
    open         NUMERIC(12,4),
    high         NUMERIC(12,4),
    low          NUMERIC(12,4),
    close        NUMERIC(12,4),
    volume       BIGINT,
    daily_return NUMERIC(10,6),
    daily_range  NUMERIC(10,6),
    ma_7         NUMERIC(12,4),
    ma_21        NUMERIC(12,4),
    ma_50        NUMERIC(12,4),
    ma_200       NUMERIC(12,4),
    volatility_21 NUMERIC(10,6),
    PRIMARY KEY (symbol, date)
);

INSERT INTO gold.daily_summary
SELECT
    s.symbol,
    s.date,
    s.company_name,
    s.sector,
    s.open,
    s.high,
    s.low,
    s.close,
    s.volume,
    s.daily_return,
    s.daily_range,
    ROUND((AVG(s.close) OVER (PARTITION BY s.symbol ORDER BY s.date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))::NUMERIC, 4) AS ma_7,
    ROUND((AVG(s.close) OVER (PARTITION BY s.symbol ORDER BY s.date ROWS BETWEEN 20 PRECEDING AND CURRENT ROW))::NUMERIC, 4) AS ma_21,
    ROUND((AVG(s.close) OVER (PARTITION BY s.symbol ORDER BY s.date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW))::NUMERIC, 4) AS ma_50,
    ROUND((AVG(s.close) OVER (PARTITION BY s.symbol ORDER BY s.date ROWS BETWEEN 199 PRECEDING AND CURRENT ROW))::NUMERIC, 4) AS ma_200,
    ROUND((STDDEV(s.daily_return) OVER (PARTITION BY s.symbol ORDER BY s.date ROWS BETWEEN 20 PRECEDING AND CURRENT ROW))::NUMERIC, 6) AS volatility_21
FROM silver.stocks s;
