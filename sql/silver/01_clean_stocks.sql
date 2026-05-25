DROP TABLE IF EXISTS silver.stocks CASCADE;

CREATE TABLE silver.stocks (
    symbol         VARCHAR(10)  NOT NULL,
    date           DATE         NOT NULL,
    open           NUMERIC(12,4),
    high           NUMERIC(12,4),
    low            NUMERIC(12,4),
    close          NUMERIC(12,4),
    adj_close      NUMERIC(12,4),
    volume         BIGINT,
    daily_return   NUMERIC(10,6),
    daily_range    NUMERIC(10,6),
    sector         VARCHAR(100),
    industry       VARCHAR(100),
    market_cap     BIGINT,
    company_name   VARCHAR(255),
    ingested_at    TIMESTAMPTZ   DEFAULT NOW(),
    PRIMARY KEY (symbol, date)
);

INSERT INTO silver.stocks (
    symbol, date, open, high, low, close, adj_close, volume,
    daily_return, daily_range, sector, industry, market_cap, company_name
)
SELECT
    s."Symbol",
    s."Date"::DATE,
    s."Open",
    s."High",
    s."Low",
    s."Close",
    s."Adj Close",
    s."Volume"::BIGINT,
    CASE WHEN s."Open" IS NOT NULL AND s."Open" <> 0
         THEN ROUND(((s."Close" - s."Open") / s."Open")::NUMERIC, 6)
         ELSE NULL END,
    CASE WHEN s."Close" IS NOT NULL AND s."Close" <> 0
         THEN ROUND(((s."High" - s."Low") / s."Close")::NUMERIC, 6)
         ELSE NULL END,
    c."Sector",
    c."Industry",
    c."Marketcap",
    c."Longname"
FROM bronze.stocks s
LEFT JOIN bronze.companies c ON c."Symbol" = s."Symbol"
WHERE s."Close" IS NOT NULL;
