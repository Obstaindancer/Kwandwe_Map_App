import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/tracking_model.dart';
import '../../providers/tracking_provider.dart';
import 'track_history_screen.dart';

class TrackingDashboardScreen extends ConsumerStatefulWidget {
  const TrackingDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TrackingDashboardScreen> createState() => _TrackingDashboardScreenState();
}

class _TrackingDashboardScreenState extends ConsumerState<TrackingDashboardScreen> {
  ActivityType _selectedActivity = ActivityType.patrol;
  final TextEditingController _nameController = TextEditingController();

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    return Scaffold(
      backgroundColor: KwandweTheme.background,
      appBar: AppBar(
        title: const Text('Tracking Dashboard'),
        backgroundColor: KwandweTheme.primary.withOpacity(0.9),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Tracks',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackHistoryScreen()));
            },
          ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTelemetryCard(trackingState),
              const SizedBox(height: 16),
              if (trackingState.status != TrackingStatus.stopped)
                Expanded(child: _buildChart(trackingState)),
              if (trackingState.status == TrackingStatus.stopped) ...[
                Expanded(child: _buildSetupCard()),
              ],
              const SizedBox(height: 16),
              _buildControls(trackingState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupCard() {
    return Card(
      color: KwandweTheme.surface.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Session',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: KwandweTheme.accent),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Session Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Activity Type'),
              const SizedBox(height: 8),
              SegmentedButton<ActivityType>(
                segments: ActivityType.values
                    .where((type) => type != ActivityType.imported)
                    .map((type) {
                  return ButtonSegment<ActivityType>(
                    value: type,
                    label: Text(type.displayName, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                selected: {_selectedActivity},
                onSelectionChanged: (Set<ActivityType> newSelection) {
                  setState(() {
                    _selectedActivity = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(TrackingState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KwandweTheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KwandweTheme.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('DISTANCE', '${((state.activeSession?.distanceMeters ?? 0) / 1000).toStringAsFixed(2)} km'),
                  _buildStatItem('DURATION', _formatDuration(state.activeSession?.durationSeconds ?? 0)),
                ],
              ),
              const Divider(height: 30, color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('SPEED', '${(state.currentSpeed * 3.6).toStringAsFixed(1)} km/h'),
                  _buildStatItem('STATUS', state.status.name.toUpperCase(), color: _getStatusColor(state.status)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.recording: return Colors.greenAccent;
      case TrackingStatus.paused: return Colors.orangeAccent;
      case TrackingStatus.stopped: return Colors.grey;
    }
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildChart(TrackingState state) {
    if (state.currentPoints.isEmpty) {
      return const Center(child: Text("Waiting for GPS data...", style: TextStyle(color: Colors.white54)));
    }

    // Take the last 60 points for the chart to keep it clean
    final points = state.currentPoints.length > 60 
      ? state.currentPoints.sublist(state.currentPoints.length - 60) 
      : state.currentPoints;

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.speed * 3.6); // Convert to km/h
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KwandweTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Speed Profile (km/h)', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: KwandweTheme.accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: KwandweTheme.accent.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(TrackingState state) {
    if (state.status == TrackingStatus.stopped) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: KwandweTheme.accent,
          foregroundColor: KwandweTheme.background,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () {
          final name = _nameController.text.isNotEmpty 
              ? _nameController.text 
              : '${_selectedActivity.displayName} ${DateFormat('dd MMM yyyy').format(DateTime.now())}';
          ref.read(trackingProvider.notifier).startNewSession(_selectedActivity, name);
        },
        child: const Text('START TRACKING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
    }

    return Row(
      children: [
        if (state.status == TrackingStatus.recording)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: KwandweTheme.caution,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => ref.read(trackingProvider.notifier).pauseSession(),
              icon: const Icon(Icons.pause),
              label: const Text('PAUSE'),
            ),
          ),
        if (state.status == TrackingStatus.paused)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => ref.read(trackingProvider.notifier).resumeSession(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('RESUME'),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: KwandweTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              ref.read(trackingProvider.notifier).stopSession();
              _nameController.clear();
            },
            icon: const Icon(Icons.stop),
            label: const Text('STOP'),
          ),
        ),
      ],
    );
  }
}
