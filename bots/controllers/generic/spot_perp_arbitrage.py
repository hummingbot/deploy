import time
from decimal import Decimal
from typing import Dict, List, Set

import pandas as pd
from pydantic import Field, validator

from hummingbot.client.config.config_data_types import ClientFieldData
from hummingbot.client.ui.interface_utils import format_df_for_printout
from hummingbot.core.data_type.common import PriceType, TradeType, PositionAction, OrderType
from hummingbot.data_feed.candles_feed.data_types import CandlesConfig
from hummingbot.strategy_v2.controllers.controller_base import ControllerBase, ControllerConfigBase
from hummingbot.strategy_v2.executors.data_types import ConnectorPair
from hummingbot.strategy_v2.executors.position_executor.data_types import PositionExecutorConfig, \
    TripleBarrierConfig
from hummingbot.strategy_v2.executors.xemm_executor.data_types import XEMMExecutorConfig
from hummingbot.strategy_v2.models.executor_actions import CreateExecutorAction, ExecutorAction, StopExecutorAction


class SpotPerpArbitrageConfig(ControllerConfigBase):
    controller_name: str = "spot_perp_arbitrage"
    candles_config: List[CandlesConfig] = []
    spot_connector: str = Field(
        default="binance",
        client_data=ClientFieldData(
            prompt=lambda e: "Enter the spot connector: ",
            prompt_on_new=True
        ))
    spot_trading_pair: str = Field(
        default="DOGE-USDT",
        client_data=ClientFieldData(
            prompt=lambda e: "Enter the spot trading pair: ",
            prompt_on_new=True
        ))
    perp_connector: str = Field(
        default="binance_perpetual",
        client_data=ClientFieldData(
            prompt=lambda e: "Enter the perp connector: ",
            prompt_on_new=True
        ))
    perp_trading_pair: str = Field(
        default="DOGE-USDT",
        client_data=ClientFieldData(
            prompt=lambda e: "Enter the perp trading pair: ",
            prompt_on_new=True
        ))
    profitability: Decimal = Field(
        default=0.002,
        client_data=ClientFieldData(
            prompt=lambda e: "Enter the minimum profitability: ",
            prompt_on_new=True
        ))
    position_size_quote: float = Field(
        default=50,
        client_data=ClientFieldData(
            prompt=lambda e: "Enter the position size in quote currency: ",
            prompt_on_new=True
        ))

    def update_markets(self, markets: Dict[str, Set[str]]) -> Dict[str, Set[str]]:
        if self.spot_connector not in markets:
            markets[self.spot_connector] = set()
        markets[self.spot_connector].add(self.spot_trading_pair)
        if self.perp_connector not in markets:
            markets[self.perp_connector] = set()
        markets[self.perp_connector].add(self.perp_trading_pair)
        return markets


class SpotPerpArbitrage(ControllerBase):

    def __init__(self, config: SpotPerpArbitrageConfig, *args, **kwargs):
        self.config = config
        super().__init__(config, *args, **kwargs)

    @property
    def spot_connector(self):
        return self.market_data_provider.connectors[self.config.spot_connector]

    @property
    def perp_connector(self):
        return self.market_data_provider.connectors[self.config.perp_connector]

    def get_current_profitability_after_fees(self):
        """
        This methods compares the profitability of buying at market in the two exchanges. If the side is TradeType.BUY
        means that the operation is long on connector 1 and short on connector 2.
        """
        spot_trading_pair = self.config.spot_trading_pair
        perp_trading_pair = self.config.perp_trading_pair

        connector_spot_price = Decimal(self.market_data_provider.get_price_for_quote_volume(
            connector_name=self.config.spot_connector,
            trading_pair=spot_trading_pair,
            quote_volume=self.config.position_size_quote,
            is_buy=True,
        ).result_price)
        connector_perp_price = Decimal(self.market_data_provider.get_price_for_quote_volume(
            connector_name=self.config.spot_connector,
            trading_pair=perp_trading_pair,
            quote_volume=self.config.position_size_quote,
            is_buy=False,
        ).result_price)
        estimated_fees_spot_connector = self.spot_connector.get_fee(
            base_currency=spot_trading_pair.split("-")[0],
            quote_currency=spot_trading_pair.split("-")[1],
            order_type=OrderType.MARKET,
            order_side=TradeType.BUY,
            amount=self.config.position_size_quote / float(connector_spot_price),
            price=connector_spot_price,
            is_maker=False,
        ).percent
        estimated_fees_perp_connector = self.perp_connector.get_fee(
            base_currency=perp_trading_pair.split("-")[0],
            quote_currency=perp_trading_pair.split("-")[1],
            order_type=OrderType.MARKET,
            order_side=TradeType.BUY,
            amount=self.config.position_size_quote / float(connector_perp_price),
            price=connector_perp_price,
            is_maker=False,
            position_action=PositionAction.OPEN
        ).percent

        estimated_trade_pnl_pct = (connector_perp_price - connector_spot_price) / connector_spot_price
        return estimated_trade_pnl_pct - estimated_fees_spot_connector - estimated_fees_perp_connector

    def is_active_arbitrage(self):
        executors = self.filter_executors(
            executors=self.executors_info,
            filter_func=lambda e: e.is_active
        )
        return len(executors) > 0

    def current_pnl_pct(self):
        executors = self.filter_executors(
            executors=self.executors_info,
            filter_func=lambda e: e.is_active
        )
        filled_amount = sum(e.filled_amount_quote for e in executors)
        return sum(e.net_pnl_quote for e in executors) / filled_amount if filled_amount > 0 else 0

    async def update_processed_data(self):
        self.processed_data = {
            "profitability": self.get_current_profitability_after_fees(),
            "active_arbitrage": self.is_active_arbitrage(),
            "current_pnl": self.current_pnl_pct()
        }

    def determine_executor_actions(self) -> List[ExecutorAction]:
        executor_actions = []
        executor_actions.extend(self.create_new_arbitrage_actions())
        executor_actions.extend(self.stop_arbitrage_actions())
        return executor_actions

    def create_new_arbitrage_actions(self):
        create_actions = []
        if not self.processed_data["active_arbitrage"] and self.processed_data["profitability"] > self.config.profitability:
            mid_price = self.market_data_provider.get_price_by_type(self.config.spot_connector, self.config.spot_trading_pair, PriceType.MidPrice)
            create_actions.append(CreateExecutorAction(
                controller_id=self.config.id,
                executor_config=PositionExecutorConfig(
                    timestamp=self.market_data_provider.time(),
                    connector_name=self.config.spot_connector,
                    trading_pair=self.config.spot_trading_pair,
                    side=TradeType.BUY,
                    amount=Decimal(self.config.position_size_quote) / mid_price,
                    triple_barrier_config=TripleBarrierConfig(open_order_type=OrderType.MARKET),
                )
            ))
            create_actions.append(CreateExecutorAction(
                controller_id=self.config.id,
                executor_config=PositionExecutorConfig(
                    timestamp=self.market_data_provider.time(),
                    connector_name=self.config.perp_connector,
                    trading_pair=self.config.perp_trading_pair,
                    side=TradeType.SELL,
                    amount=Decimal(self.config.position_size_quote) / mid_price,
                    triple_barrier_config=TripleBarrierConfig(open_order_type=OrderType.MARKET),
                ))
            )
            return create_actions

    def stop_arbitrage_actions(self):
        stop_actions = []
        if self.processed_data["current_pnl"] > 0.003:
            executors = self.filter_executors(
                executors=self.executors_info,
                filter_func=lambda e: e.is_active
            )
            for executor in executors:
                stop_actions.append(StopExecutorAction(controller_id=self.config.id, executor_id=executor.id))

    def to_format_status(self) -> List[str]:
        return [f"Current profitability: {self.processed_data['profitability']} | Min profitability: {self.config.profitability}",
                f"Active arbitrage: {self.processed_data['active_arbitrage']}",
                f"Current PnL: {self.processed_data['current_pnl']}"]
