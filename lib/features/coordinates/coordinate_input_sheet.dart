import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'coordinate_parser.dart';

/// Bottom sheet for pasting or typing GPS coordinates.
/// Returns a LatLng to the caller on success.
class CoordinateInputSheet extends StatefulWidget {
  const CoordinateInputSheet({super.key});

  @override
  State<CoordinateInputSheet> createState() => _CoordinateInputSheetState();
}

class _CoordinateInputSheetState extends State<CoordinateInputSheet> {
  final _controller = TextEditingController();
  String? _error;
  LatLng? _parsed;

  void _tryParse(String value) {
    final result = CoordinateParser.parse(value);
    setState(() {
      _parsed = result;
      _error = value.trim().isEmpty
          ? null
          : result == null
              ? 'Could not read coordinates — try: -33.1234, 26.5678'
              : null;
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      _tryParse(data.text!);
    }
  }

  void _confirm() {
    if (_parsed != null) {
      Navigator.of(context).pop(_parsed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Go to Coordinates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste rhino collar alert or type coordinates',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '-33.1234, 26.5678',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: const Color(0xFF3A3A3A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              errorText: _error,
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, color: Colors.white54),
                tooltip: 'Paste from clipboard',
                onPressed: _pasteFromClipboard,
              ),
            ),
            onChanged: _tryParse,
          ),
          if (_parsed != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 16),
                const SizedBox(width: 6),
                Text(
                  CoordinateParser.format(_parsed!.latitude, _parsed!.longitude),
                  style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
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
                child: ElevatedButton.icon(
                  onPressed: _parsed != null ? _confirm : null,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Go to Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A843),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
