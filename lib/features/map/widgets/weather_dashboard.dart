import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../map_provider.dart';
import '../../../models/weather_model.dart';

class WeatherDashboard extends ConsumerWidget {
  const WeatherDashboard({super.key});

  String _getWindDirectionString(int bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) % 360) / 45;
    return directions[index.floor()];
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showMoonPhaseCalendar(BuildContext context) {
    final today = DateTime.now();
    final phases = List.generate(28, (index) {
      final date = today.add(Duration(days: index));
      return {
        'date': '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
        'phase': WeatherModel.calculateMoonPhase(date),
        'emoji': WeatherModel.calculateMoonPhaseEmoji(date),
      };
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Lunar Calendar (Next 28 Days)',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: phases.length,
                  itemBuilder: (context, index) {
                    final phaseData = phases[index];
                    return ListTile(
                      leading: Text(phaseData['emoji']!, style: const TextStyle(fontSize: 24)),
                      title: Text(phaseData['phase']!, style: const TextStyle(color: Colors.white)),
                      trailing: Text(phaseData['date']!, style: const TextStyle(color: Colors.white54)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    final weather = mapState.weather;

    if (weather == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Environment Conditions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeatherItem('${weather.temperature}°C', 'Temp', icon: Icons.thermostat, iconColor: Colors.orange),
              _buildWeatherItem(
                  '${weather.windSpeed} km/h ${_getWindDirectionString(weather.windDirection)}', 'Wind', icon: Icons.air, iconColor: Colors.lightBlue),
              _buildWeatherItem(weather.weatherDescription, 'Forecast', emoji: weather.weatherEmoji),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeatherItem(_formatTime(weather.sunrise), 'Sunrise', icon: Icons.wb_sunny_outlined, iconColor: Colors.yellow),
              _buildWeatherItem(_formatTime(weather.sunset), 'Sunset', icon: Icons.nights_stay_outlined, iconColor: Colors.deepOrangeAccent),
              _buildWeatherItem(
                weather.moonPhase, 
                'Moon', 
                emoji: weather.moonPhaseEmoji,
                onTap: () => _showMoonPhaseCalendar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherItem(String value, String label, {IconData? icon, Color? iconColor, String? emoji, VoidCallback? onTap}) {
    final content = Column(
      children: [
        if (emoji != null)
          Text(emoji, style: const TextStyle(fontSize: 22))
        else if (icon != null)
          Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.transparent, // Ensures the whole area is tappable
          child: content,
        ),
      );
    }
    return content;
  }
}
