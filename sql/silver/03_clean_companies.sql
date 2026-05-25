DROP TABLE IF EXISTS silver.companies CASCADE;

CREATE TABLE silver.companies (
    symbol              VARCHAR(10)  NOT NULL PRIMARY KEY,
    exchange            VARCHAR(10),
    short_name          VARCHAR(255),
    long_name           VARCHAR(500),
    sector              VARCHAR(100),
    industry            VARCHAR(100),
    current_price       NUMERIC(12,4),
    market_cap          BIGINT,
    ebitda              NUMERIC(16,2),
    revenue_growth      NUMERIC(8,4),
    city                VARCHAR(100),
    state               VARCHAR(50),
    country             VARCHAR(100),
    full_time_employees INTEGER,
    weight              NUMERIC(10,8),
    ingested_at         TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO silver.companies (
    symbol, exchange, short_name, long_name, sector, industry,
    current_price, market_cap, ebitda, revenue_growth,
    city, state, country, full_time_employees, weight
)
SELECT
    "Symbol", "Exchange", "Shortname", "Longname", "Sector", "Industry",
    "Currentprice", "Marketcap", "Ebitda", "Revenuegrowth",
    "City", "State", "Country", "Fulltimeemployees"::INTEGER, "Weight"
FROM bronze.companies;
