import os
import streamlit as st
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from datetime import datetime, timedelta
import psycopg2

DB_CONFIG = {
    "host": os.getenv("STOCK_DB_HOST", "localhost"),
    "port": os.getenv("STOCK_DB_PORT", "5432"),
    "dbname": os.getenv("STOCK_DB_NAME", "sp500_db"),
    "user": os.getenv("STOCK_DB_USER", "postgres"),
    "password": os.getenv("STOCK_DB_PASSWORD", "babyLEMON"),
}

@st.cache_data(ttl=600)
def query(sql):
    conn = psycopg2.connect(**DB_CONFIG)
    df = pd.read_sql(sql, conn)
    conn.close()
    return df

def title_case_name(name):
    return " ".join(word[:1].upper() + word[1:] for word in str(name).split("_"))

def title_case_columns(df):
    return df.rename(columns={col: title_case_name(col) for col in df.columns})

st.set_page_config(page_title="S&P 500 Stock Dashboard", layout="wide")
st.title("S&P 500 Stock Analysis Dashboard")

# ── Sidebar ──
st.sidebar.header("Controls")

latest_date = query("SELECT MAX(date)::TEXT FROM gold.daily_summary").iloc[0, 0]
symbols = query("SELECT DISTINCT symbol FROM gold.daily_summary ORDER BY symbol")["symbol"].tolist()
sectors = query("SELECT DISTINCT sector FROM gold.daily_summary ORDER BY sector")["sector"].tolist()

view = st.sidebar.radio("View", ["Sector Overview", "Symbol Deep Dive", "Volatility Monitor"])

# ── Sector Overview ──
if view == "Sector Overview":
    selected_sector = st.sidebar.selectbox("Sector", ["All"] + sectors, key="so_sector")

    st.subheader(f"Sector Performance — {latest_date}")

    if selected_sector == "All":
        sector_df = query(f"""
            SELECT sector, num_companies, avg_daily_return, total_volume,
                   top_gainer_symbol, top_gainer_return,
                   top_loser_symbol, top_loser_return
            FROM gold.sector_performance
            WHERE date = '{latest_date}'
            ORDER BY avg_daily_return DESC
        """)
    else:
        sector_df = query(f"""
            SELECT sector, num_companies, avg_daily_return, total_volume,
                   top_gainer_symbol, top_gainer_return,
                   top_loser_symbol, top_loser_return
            FROM gold.sector_performance
            WHERE date = '{latest_date}' AND sector = '{selected_sector}'
            ORDER BY avg_daily_return DESC
        """)

    col1, col2 = st.columns([2, 1])
    with col1:
        fig = px.bar(sector_df, x="sector", y="avg_daily_return",
                     color="avg_daily_return", color_continuous_scale="RdYlGn",
                     title="Avg Daily Return by Sector",
                     labels={
                         "sector": "Sector",
                         "avg_daily_return": "Avg Daily Return",
                     })
        fig.update_layout(xaxis_tickangle=-45)
        st.plotly_chart(fig, use_container_width=True)
    with col2:
        sector_display = title_case_columns(sector_df)
        st.dataframe(sector_display.style.format({
            "Avg Daily Return": "{:.4%}",
            "Total Volume": "{:,.0f}",
            "Top Gainer Return": "{:.4%}",
            "Top Loser Return": "{:.4%}",
        }), height=500)

    # Cumulative sector returns
    st.subheader("Cumulative Sector Returns (2024)")
    cumul = query(f"""
        SELECT date, sector, avg_daily_return
        FROM gold.sector_performance
        WHERE date >= '2024-01-01'
          {'AND sector = ' + chr(39) + selected_sector + chr(39) if selected_sector != 'All' else ''}
        ORDER BY date
    """)
    if not cumul.empty:
        cumul["cum_return"] = cumul.groupby("sector")["avg_daily_return"].cumsum()
        fig2 = px.line(cumul, x="date", y="cum_return", color="sector",
                       title=f"Cumulative Return {' - ' + selected_sector if selected_sector != 'All' else 'by Sector'}",
                       labels={
                           "date": "Date",
                           "cum_return": "Cum Return",
                           "sector": "Sector",
                       })
        st.plotly_chart(fig2, use_container_width=True)

    # Stock list for selected sector
    if selected_sector != "All":
        st.subheader(f"Stocks in {selected_sector}")
        stock_list = query(f"""
            SELECT symbol, company_name, close, daily_return, daily_range, volume
            FROM gold.daily_summary
            WHERE date = '{latest_date}' AND sector = '{selected_sector}'
            ORDER BY daily_return DESC
        """)
        stock_display = title_case_columns(stock_list)
        st.dataframe(stock_display.style.format({
            "Close": "${:.2f}",
            "Daily Return": "{:.4%}",
            "Daily Range": "{:.4%}",
            "Volume": "{:,.0f}",
        }), height=400, use_container_width=True)

# ── Symbol Deep Dive ──
elif view == "Symbol Deep Dive":
    selected_symbol = st.sidebar.selectbox("Symbol", symbols, key="dd_symbol")
    st.subheader(f"{selected_symbol} — Price & Moving Averages")

    df = query(f"""
        SELECT date, open, high, low, close, volume,
               ma_7, ma_21, ma_50, ma_200
        FROM gold.daily_summary
        WHERE symbol = '{selected_symbol}'
        ORDER BY date DESC LIMIT 365
    """)
    df = df.sort_values("date")

    fig = go.Figure()
    fig.add_trace(go.Candlestick(x=df["date"],
        open=df["open"], high=df["high"], low=df["low"], close=df["close"],
        name="Price"))
    for ma, col, name in [("ma_7", "orange", "MA-7"), ("ma_21", "blue", "MA-21"),
                           ("ma_50", "green", "MA-50"), ("ma_200", "red", "MA-200")]:
        fig.add_trace(go.Scatter(x=df["date"], y=df[ma], mode="lines",
                      line=dict(color=col, width=1), name=name))
    fig.update_layout(xaxis_rangeslider_visible=False, height=600)
    st.plotly_chart(fig, use_container_width=True)

    fig2 = px.bar(df, x="date", y="volume", title="Volume",
                  labels={"date": "Date", "volume": "Volume"})
    st.plotly_chart(fig2, use_container_width=True)

    last = df.iloc[-1]
    cols = st.columns(4)
    cols[0].metric("Close", f"${last['close']:.2f}")
    cols[1].metric("MA-7", f"${last['ma_7']:.2f}")
    cols[2].metric("MA-21", f"${last['ma_21']:.2f}")
    cols[3].metric("Volume", f"{last['volume']:,.0f}")

    signals = query(f"""
        SELECT date, crossover_7_21, crossover_21_50
        FROM gold.moving_crossovers
        WHERE symbol = '{selected_symbol}'
          AND crossover_7_21 IS NOT NULL
        ORDER BY date DESC LIMIT 10
    """)
    if not signals.empty:
        st.subheader("Recent Crossover Signals")
        st.dataframe(title_case_columns(signals))

# ── Volatility Monitor ──
elif view == "Volatility Monitor":
    selected_sector_v = st.sidebar.selectbox("Sector", ["All"] + sectors, key="vm_sector")
    st.subheader("Monthly Volatility Rank")

    month = query("SELECT MAX(year_month)::TEXT FROM gold.monthly_volatility").iloc[0, 0]
    rank_df = query(f"""
        SELECT symbol, company_name, sector, avg_daily_range,
               avg_volatility, total_return, rank_by_vol
        FROM gold.monthly_volatility
        WHERE year_month = '{month}'::DATE
          {'AND sector = ' + chr(39) + selected_sector_v + chr(39) if selected_sector_v != 'All' else ''}
        ORDER BY rank_by_vol
        LIMIT 20
    """)

    col1, col2 = st.columns(2)
    with col1:
        fig = px.bar(rank_df, x="symbol", y="avg_volatility",
                     color="sector", title=f"Top 20 Volatile Stocks — {month}",
                     labels={
                         "symbol": "Symbol",
                         "avg_volatility": "Avg Volatility",
                         "sector": "Sector",
                     })
        st.plotly_chart(fig, use_container_width=True)
    with col2:
        fig2 = px.scatter(rank_df, x="avg_volatility", y="total_return",
                          color="sector", hover_name="symbol", size="avg_daily_range",
                          title="Volatility vs Return",
                          labels={
                              "avg_volatility": "Avg Volatility",
                              "total_return": "Total Return",
                              "avg_daily_range": "Avg Daily Range",
                              "sector": "Sector",
                          })
        st.plotly_chart(fig2, use_container_width=True)

    rank_display = title_case_columns(rank_df)
    st.dataframe(rank_display.style.format({
        "Avg Daily Range": "{:.4%}",
        "Avg Volatility": "{:.4%}",
        "Total Return": "{:.4%}",
    }), use_container_width=True)
