import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo numérico con botones −/+ grandes y accesos rápidos (+1, +5…), pensado
/// para puntuar deprisa en la pista. Trabaja sobre un [TextEditingController].
class QuickNumberField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int min;
  final List<int> quickAdds;
  const QuickNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.min = 0,
    this.quickAdds = const [1, 5],
  });

  @override
  State<QuickNumberField> createState() => _QuickNumberFieldState();
}

class _QuickNumberFieldState extends State<QuickNumberField> {
  int get _value => int.tryParse(widget.controller.text.trim()) ?? 0;

  void _set(int v) {
    final nv = v < widget.min ? widget.min : v;
    widget.controller.text = nv.toString();
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filledTonal(
              iconSize: 28,
              onPressed: () => _set(_value - 1),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextFormField(
                  controller: widget.controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Obligatorio';
                    if (int.tryParse(val.trim()) == null) return 'Número';
                    return null;
                  },
                ),
              ),
            ),
            IconButton.filledTonal(
              iconSize: 28,
              onPressed: () => _set(_value + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final q in widget.quickAdds)
              ActionChip(
                label: Text('+$q'),
                onPressed: () => _set(_value + q),
              ),
            ActionChip(
              avatar: Icon(Icons.refresh, size: 16, color: primary),
              label: const Text('0'),
              onPressed: () => _set(0),
            ),
          ],
        ),
      ],
    );
  }
}
