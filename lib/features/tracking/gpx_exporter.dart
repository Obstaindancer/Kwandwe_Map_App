import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/tracking_model.dart';

class GpxExporter {
  static Future<void> exportAndShare(TrackSession session, List<TrackPoint> points) async {
    final gpxContent = _buildGpx(session, points);

    final directory = await getApplicationDocumentsDirectory();
    final sanitizedName = session.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${directory.path}/${sanitizedName}_${session.id.substring(0, 5)}.gpx');
    
    await file.writeAsString(gpxContent);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Track: ${session.name}');
  }

  static String _buildGpx(TrackSession session, List<TrackPoint> points) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Kwandwe Map App" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(session.name)}</name>');
    buffer.writeln('    <desc>Activity: ${session.activityType.displayName}</desc>');
    buffer.writeln('    <time>${session.startTime.toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(session.name)}</name>');
    buffer.writeln('    <trkseg>');
    
    for (var point in points) {
      buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      buffer.writeln('        <ele>${point.altitude}</ele>');
      buffer.writeln('        <time>${point.timestamp.toUtc().toIso8601String()}</time>');
      // Optional: add speed as extension or comment if needed
      buffer.writeln('      </trkpt>');
    }
    
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    
    return buffer.toString();
  }

  static String _escapeXml(String text) {
    return text.replaceAll('&', '&amp;')
               .replaceAll('<', '&lt;')
               .replaceAll('>', '&gt;')
               .replaceAll('"', '&quot;')
               .replaceAll("'", '&apos;');
  }
}
