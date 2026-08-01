import 'package:flutter/material.dart';

import '../utils/currency_formatter.dart';

class PriceWidget extends StatelessWidget {
  final double? price;
  final String? label;
  final TextStyle? style;
  final bool prominent;

  const PriceWidget({
    super.key,
    required this.price,
    this.label,
    this.style,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = CurrencyFormatter.displayPrice(price, label: label);
    final isFree = price != null && price == 0;
    final isContact = price == null;

    final defaultStyle = prominent
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isFree
                  ? Colors.green.shade700
                  : isContact
                      ? Colors.grey.shade600
                      : Theme.of(context).colorScheme.primary,
            )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isFree
                  ? Colors.green.shade700
                  : isContact
                      ? Colors.grey.shade600
                      : Theme.of(context).colorScheme.primary,
            );

    return Text(text, style: style ?? defaultStyle);
  }
}

class EstimatedPriceWidget extends StatelessWidget {
  final double? price;
  final String? label;

  const EstimatedPriceWidget({
    super.key,
    required this.price,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PriceWidget(price: price, label: label, prominent: true),
        if (price != null && price! > 0)
          Text(
            'Estimated price',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
          ),
      ],
    );
  }
}
