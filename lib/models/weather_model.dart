class WeatherModel {
  final double temperature;
  final double windSpeed;
  final int windDirection;
  final int weatherCode;
  final DateTime sunrise;
  final DateTime sunset;
  final String moonPhase;
  final String moonPhaseEmoji;

  WeatherModel({
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.sunrise,
    required this.sunset,
    required this.moonPhase,
    required this.moonPhaseEmoji,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    return WeatherModel(
      temperature: (current['temperature_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      windDirection: (current['wind_direction_10m'] as num).toInt(),
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      sunrise: DateTime.parse((daily['sunrise'] as List)[0] as String),
      sunset: DateTime.parse((daily['sunset'] as List)[0] as String),
      moonPhase: calculateMoonPhase(DateTime.now()),
      moonPhaseEmoji: calculateMoonPhaseEmoji(DateTime.now()),
    );
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0: return "Clear sky";
      case 1: return "Mainly clear";
      case 2: return "Partly cloudy";
      case 3: return "Overcast";
      case 45: case 48: return "Fog";
      case 51: case 53: case 55: return "Drizzle";
      case 56: case 57: return "Freezing Drizzle";
      case 61: case 63: case 65: return "Rain";
      case 66: case 67: return "Freezing Rain";
      case 71: case 73: case 75: return "Snow fall";
      case 77: return "Snow grains";
      case 80: case 81: case 82: return "Rain showers";
      case 85: case 86: return "Snow showers";
      case 95: return "Thunderstorm";
      case 96: case 99: return "Thunderstorm with hail";
      default: return "Unknown";
    }
  }

  String get weatherEmoji {
    switch (weatherCode) {
      case 0: case 1: return "☀️";
      case 2: return "⛅";
      case 3: return "☁️";
      case 45: case 48: return "🌫️";
      case 51: case 53: case 55: case 56: case 57: return "🌦️";
      case 61: case 63: case 65: case 66: case 67: case 80: case 81: case 82: return "🌧️";
      case 71: case 73: case 75: case 77: case 85: case 86: return "❄️";
      case 95: case 96: case 99: return "⛈️";
      default: return "🌡️";
    }
  }

  static double _calculatePhaseNumber(DateTime date) {
    // A simple approximate algorithm for moon phase
    int year = date.year;
    int month = date.month;
    int day = date.day;

    if (month < 3) {
      year--;
      month += 12;
    }

    ++month;
    int c = 365.25 * year ~/ 1;
    int e = 30.6 * month ~/ 1;
    double jd = c + e + day - 694039.09; // Known reference date
    double phase = jd / 29.5305882;
    return phase - phase.floor();
  }

  static String calculateMoonPhase(DateTime date) {
    double phase = _calculatePhaseNumber(date);

    if (phase < 0.03 || phase > 0.97) return "New Moon";
    if (phase < 0.22) return "Waxing Crescent";
    if (phase < 0.28) return "First Quarter";
    if (phase < 0.47) return "Waxing Gibbous";
    if (phase < 0.53) return "Full Moon";
    if (phase < 0.72) return "Waning Gibbous";
    if (phase < 0.78) return "Last Quarter";
    return "Waning Crescent";
  }

  static String calculateMoonPhaseEmoji(DateTime date) {
    double phase = _calculatePhaseNumber(date);
    if (phase < 0.03 || phase > 0.97) return "🌑";
    if (phase < 0.22) return "🌒";
    if (phase < 0.28) return "🌓";
    if (phase < 0.47) return "🌔";
    if (phase < 0.53) return "🌕";
    if (phase < 0.72) return "🌖";
    if (phase < 0.78) return "🌗";
    return "🌘";
  }
}
