import 'package:flutter/material.dart';
import 'package:komodo_dex/blocs/swap_history_bloc.dart';
import 'package:komodo_dex/localizations.dart';
import 'package:komodo_dex/model/order.dart';
import 'package:komodo_dex/model/swap.dart';
import 'package:komodo_dex/model/swap_provider.dart';
import 'package:komodo_dex/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' as math;

class OrderFill extends StatefulWidget {
  const OrderFill(this.order, {this.size = 30});

  final Order order;
  final double size;

  @override
  _OrderFillState createState() => _OrderFillState();
}

class _OrderFillState extends State<OrderFill> {
  SwapProvider swapProvider;

  @override
  Widget build(BuildContext context) {
    swapProvider ??= Provider.of<SwapProvider>(context);

    return Row(
      children: <Widget>[
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: FillPainter(
              context: context,
              order: widget.order,
              swapProvider: swapProvider,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context).orderFilled(cutTrailingZeros(
              (_getFill(widget.order) * 100).toStringAsPrecision(3))),
          style: Theme.of(context).textTheme.body2,
        ),
      ],
    );
  }

  double _getFill(Order order) {
    if (order.startedSwaps == null || order.startedSwaps.isEmpty) return 0;

    double fill = 0;
    for (String swapId in order.startedSwaps) {
      final Swap swap = swapProvider.swap(swapId);
      if (swap == null) continue;
      fill += double.parse(swap.result.myInfo.myAmount) /
          double.parse(order.baseAmount);
    }
    return fill;
  }
}

class FillPainter extends CustomPainter {
  FillPainter({
    @required this.context,
    @required this.order,
    @required this.swapProvider,
  });

  final BuildContext context;
  final Order order;
  final SwapProvider swapProvider;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Theme.of(context).highlightColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2, paint);

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 1.1 / 2;

    double fillProgress = 0;
    for (String swapId in order.startedSwaps) {
      final Swap swap = swapProvider.swap(swapId);
      if (swap == null) continue;

      fillPaint..color = swapHistoryBloc.getColorStatus(swap.status);

      final double swapFill = double.parse(swap.result.myInfo.myAmount) /
          double.parse(order.baseAmount);

      canvas.drawArc(
          Rect.fromCircle(center: center, radius: size.width / 4),
          math.radians(-90 + fillProgress * 360),
          math.radians(swapFill * 360),
          false,
          fillPaint);
      fillProgress += swapFill;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
