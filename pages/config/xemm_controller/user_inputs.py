import streamlit as st


def user_inputs():
    c1, c2, c3, c4, c5 = st.columns([1, 1, 1, 1, 1])
    with c1:
        maker_connector = st.text_input("Maker Connector", value="kucoin")
        maker_trading_pair = st.text_input("Maker Trading Pair", value="LBR-USDT")
    with c2:
        taker_connector = st.text_input("Taker Connector", value="okx")
        taker_trading_pair = st.text_input("Taker Trading Pair", value="LBR-USDT")
    with c3:
        min_profitability = st.number_input("Min Profitability (%)", value=0.2, step=0.01) / 100
        max_profitability = st.number_input("Max Profitability (%)", value=1.0, step=0.01) / 100
    with c4:
        buy_maker_levels = st.number_input("Buy Maker Levels", value=1, step=1)
        buy_targets_amounts = []
        c41, c42 = st.columns([1, 1])
        for i in range(buy_maker_levels):
            with c41:
                target_profitability = st.number_input(f"Target Profitability {i + 1} B% ", value=0.3, step=0.01)
            with c42:
                amount = st.number_input(f"Amount {i + 1}B Quote", value=10, step=1)
            buy_targets_amounts.append([target_profitability / 100, amount])
    with c5:
        sell_maker_levels = st.number_input("Sell Maker Levels", value=1, step=1)
        sell_targets_amounts = []
        c51, c52 = st.columns([1, 1])
        for i in range(sell_maker_levels):
            with c51:
                target_profitability = st.number_input(f"Target Profitability {i + 1}S %", value=0.3, step=0.001)
            with c52:
                amount = st.number_input(f"Amount {i + 1} S Quote", value=10, step=1)
            sell_targets_amounts.append([target_profitability / 100, amount])
    return {
        "controller_name": "xemm_multiple_levels",
        "controller_type": "generic",
        "maker_connector": maker_connector,
        "maker_trading_pair": maker_trading_pair,
        "taker_connector": taker_connector,
        "taker_trading_pair": taker_trading_pair,
        "min_profitability": min_profitability,
        "max_profitability": max_profitability,
        "buy_levels_targets_amount": buy_targets_amounts,
        "sell_levels_targets_amount": sell_targets_amounts
    }
