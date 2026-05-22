import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/pin_model.dart';

class PinSelectionSheet extends StatefulWidget {
  const PinSelectionSheet({super.key});

  @override
  State<PinSelectionSheet> createState() => _PinSelectionSheetState();
}

class _PinSelectionSheetState extends State<PinSelectionSheet> {
  PinType? _selectedType;
  final _labelController = TextEditingController();

  final List<Map<String, dynamic>> _pinCategories = [
    {
      'header': 'Security / Anti-Poaching',
      'items': [
        PinType.rhinoRed,
        PinType.rhinoAmber,
        PinType.rhinoGray,
      ],
    },
    {
      'header': 'Field Guides',
      'items': [
        PinType.sighting,
        PinType.waypoint,
      ],
    },
    {
      'header': 'Farm Staff',
      'items': [
        PinType.maintenance,
      ],
    },
  ];

  Color _getColorForType(PinType type) {
    // We create a dummy pin just to grab its color property safely
    return MapPin(
      id: '',
      position: const LatLng(0, 0),
      label: '',
      type: type,
      createdAt: DateTime.now(),
    ).colour;
  }

  String _getLabelForType(PinType type) {
    return MapPin(
      id: '',
      position: const LatLng(0, 0),
      label: '',
      type: type,
      createdAt: DateTime.now(),
    ).typeLabel;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selectedType == null) return;
    final label = _labelController.text.trim().isEmpty
        ? _getLabelForType(_selectedType!)
        : _labelController.text.trim();
    Navigator.of(context).pop({'type': _selectedType, 'label': label});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drop a Pin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ..._pinCategories.map((category) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['header'] as String,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (category['items'] as List<PinType>).map((type) {
                      final isSelected = _selectedType == type;
                      final color = _getColorForType(type);
                      return ChoiceChip(
                        label: Text(_getLabelForType(type)),
                        selected: isSelected,
                        selectedColor: color.withOpacity(0.3),
                        backgroundColor: const Color(0xFF3A3A3A),
                        labelStyle: TextStyle(
                          color: isSelected ? color : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? color : Colors.transparent,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = type;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
            if (_selectedType != null) ...[
              TextField(
                controller: _labelController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Optional label (e.g. Rhino BRF23, Broken pipe)',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF3A3A3A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedType != null ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A843),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Drop Pin'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
