import 'package:flutter/material.dart';

import '../screens/map/intercity_place_picker_screens.dart';
import '../services/geocoding_service.dart';

class IntercityCitySelectionField extends StatelessWidget {
  const IntercityCitySelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.pickerBuilder,
  });

  final String label;
  final KazakhstanSettlement? value;
  final ValueChanged<KazakhstanSettlement> onChanged;
  final WidgetBuilder? pickerBuilder;

  Future<void> _select(BuildContext context) async {
    final selected = await Navigator.push<KazakhstanSettlement>(
      context,
      MaterialPageRoute(
        builder: pickerBuilder ?? (_) => const IntercityCityPickerScreen(),
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('intercity_city_field_${label.toLowerCase()}'),
    onTap: () => _select(context),
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.location_city_outlined),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(value?.displayName ?? 'Выберите город'),
    ),
  );
}

class IntercitySeatsSelector extends StatelessWidget {
  const IntercitySeatsSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.maximum = 7,
  });

  final int value;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'Количество мест',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      IconButton(
        key: const Key('intercity_seats_decrease'),
        tooltip: 'Уменьшить',
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Semantics(
        label: 'Количество мест: $value',
        child: Text(
          '$value',
          key: const Key('intercity_seats_value'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      IconButton(
        key: const Key('intercity_seats_increase'),
        tooltip: 'Увеличить',
        onPressed: value < maximum ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}
