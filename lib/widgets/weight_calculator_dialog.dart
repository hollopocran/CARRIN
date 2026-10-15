import 'package:flutter/material.dart';

/// Modal dialog for calculating product weight based on price per kg and total paid.
class WeightCalculatorDialog extends StatefulWidget {
  final String initialPrice;
  final void Function(String pricePerKg, String calculatedWeight) onApplied;

  const WeightCalculatorDialog({
    super.key,
    required this.initialPrice,
    required this.onApplied,
  });

  /// Convenience method to show the animated dialog directly with text controllers.
  static Future<void> show(
    BuildContext context, {
    required TextEditingController unitPriceCtrl,
    required TextEditingController qtyCtrl,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => WeightCalculatorDialog(
        initialPrice: unitPriceCtrl.text,
        onApplied: (pricePerKg, calculatedWeight) {
          unitPriceCtrl.text = pricePerKg;
          qtyCtrl.text = calculatedWeight;
        },
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WeightCalculatorDialog> createState() => _WeightCalculatorDialogState();
}

class _WeightCalculatorDialogState extends State<WeightCalculatorDialog> {
  late final TextEditingController _pricePerKgCtrl;
  late final TextEditingController _totalPaidCtrl;

  @override
  void initState() {
    super.initState();
    _pricePerKgCtrl = TextEditingController(text: widget.initialPrice);
    _totalPaidCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _pricePerKgCtrl.dispose();
    _totalPaidCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final double p = double.tryParse(_pricePerKgCtrl.text.replaceAll(',', '.')) ?? 0;
    final double t = double.tryParse(_totalPaidCtrl.text.replaceAll(',', '.')) ?? 0;
    if (p > 0 && t > 0) {
      final calculatedWeight = (t / p).toStringAsFixed(3).replaceAll('.', ',');
      widget.onApplied(_pricePerKgCtrl.text, calculatedWeight);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Calculadora de Peso', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Informe os valores para descobrir o peso:', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: _pricePerKgCtrl,
            decoration: const InputDecoration(
              labelText: 'Preço por Kg',
              hintText: '0,00',
              prefixText: 'R\$ ',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: UnderlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totalPaidCtrl,
            decoration: const InputDecoration(
              labelText: 'Total Pago',
              hintText: '0,00',
              prefixText: 'R\$ ',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: UnderlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _apply(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _apply,
          child: const Text('Aplicar Peso', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
