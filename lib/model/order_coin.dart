import 'package:decimal/decimal.dart';
import 'package:komodo_dex/model/coin.dart';
import 'package:komodo_dex/model/orderbook.dart';

class OrderCoin {
  OrderCoin(
      {this.coinRel,
      this.coinBase,
      this.orderbook,
      this.bestPrice,
      this.maxVolume});

  Coin coinRel;
  Coin coinBase;
  Orderbook orderbook;
  String bestPrice;
  double maxVolume;

  String getBuyAmount(String amountToSell) {
    String buyAmount = 0.toString();
    buyAmount = (Decimal.parse(amountToSell) / Decimal.parse(bestPrice))
        .toStringAsFixed(8);
    if (double.parse(buyAmount) == 0) {
      buyAmount = 0.toStringAsFixed(0);
    }
    if (double.parse(buyAmount) >= maxVolume) {
      buyAmount = maxVolume.toString();
    }
    return buyAmount;
  }
}
