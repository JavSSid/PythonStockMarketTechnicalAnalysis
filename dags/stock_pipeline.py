import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator

DEFAULT_ARGS = {
    "owner": "data_engineering",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": False,
}

SQL_DIR = Path("/opt/airflow/sql")

with DAG(
    dag_id="stock_pipeline",
    start_date=datetime(2024, 1, 1),
    schedule="0 6 * * *",
    catchup=False,
    default_args=DEFAULT_ARGS,
    description="Bronze → Silver → Gold stock data pipeline",
    tags=["stocks", "s&p500"],
    template_searchpath=str(SQL_DIR),
) as dag:

    create_schemas = PostgresOperator(
        task_id="create_schemas",
        postgres_conn_id="stock_db",
        sql="CREATE SCHEMA IF NOT EXISTS silver; CREATE SCHEMA IF NOT EXISTS gold;",
    )

    clean_stocks = PostgresOperator(
        task_id="clean_stocks",
        postgres_conn_id="stock_db",
        sql="sql/silver/01_clean_stocks.sql",
    )

    clean_index = PostgresOperator(
        task_id="clean_index",
        postgres_conn_id="stock_db",
        sql="sql/silver/02_clean_index.sql",
    )

    clean_companies = PostgresOperator(
        task_id="clean_companies",
        postgres_conn_id="stock_db",
        sql="sql/silver/03_clean_companies.sql",
    )

    daily_summary = PostgresOperator(
        task_id="daily_summary",
        postgres_conn_id="stock_db",
        sql="sql/gold/01_daily_summary.sql",
    )

    sector_performance = PostgresOperator(
        task_id="sector_performance",
        postgres_conn_id="stock_db",
        sql="sql/gold/02_sector_performance.sql",
    )

    moving_crossovers = PostgresOperator(
        task_id="moving_crossovers",
        postgres_conn_id="stock_db",
        sql="sql/gold/03_moving_crossovers.sql",
    )

    monthly_volatility = PostgresOperator(
        task_id="monthly_volatility",
        postgres_conn_id="stock_db",
        sql="sql/gold/04_monthly_volatility_rank.sql",
    )

    (
        create_schemas
        >> [clean_stocks, clean_index, clean_companies]
        >> daily_summary
        >> [sector_performance, moving_crossovers, monthly_volatility]
    )
