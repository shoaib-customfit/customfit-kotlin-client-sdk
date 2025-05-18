import 'dart:async';
import 'dart:math' as math;
import '../../logging/logger.dart';
import '../util/synchronization.dart';

/// A class to track performance metrics across the SDK
class MetricsCollector {
  static const String _source = 'MetricsCollector';

  // Singleton instance
  static MetricsCollector? _instance;

  // Metrics storage
  final Map<String, List<int>> _timingMetrics = {};
  final Map<String, int> _counterMetrics = {};
  final Map<String, double> _gaugeMetrics = {};

  // Lock for thread safety
  final _metricsLock = Object();

  // In-memory buffer size limits
  static const int _maxTimingSamples = 100;

  // Histogram buckets for timing metrics (in ms)
  final List<int> _histogramBuckets = [
    1,
    5,
    10,
    25,
    50,
    100,
    250,
    500,
    1000,
    2500,
    5000,
    10000
  ];
  final Map<String, Map<int, int>> _histograms = {};

  // Private constructor
  MetricsCollector._();

  /// Get the singleton instance
  static MetricsCollector get instance {
    _instance ??= MetricsCollector._();
    return _instance!;
  }

  /// Record the timing of an operation in milliseconds
  void recordTiming(String operation, int durationMs) {
    synchronized(_metricsLock, () {
      // Initialize timing list if needed
      _timingMetrics.putIfAbsent(operation, () => []);

      // Add timing data
      final timings = _timingMetrics[operation]!;
      timings.add(durationMs);

      // Trim to keep buffer size manageable
      if (timings.length > _maxTimingSamples) {
        timings.removeAt(0);
      }

      // Update histogram
      _histograms.putIfAbsent(operation, () => {});
      final histogram = _histograms[operation]!;

      // Find the appropriate bucket
      int bucketIndex =
          _histogramBuckets.indexWhere((bucket) => durationMs <= bucket);
      if (bucketIndex == -1) bucketIndex = _histogramBuckets.length;

      final bucket = bucketIndex < _histogramBuckets.length
          ? _histogramBuckets[bucketIndex]
          : _histogramBuckets.last * 2;

      histogram[bucket] = (histogram[bucket] ?? 0) + 1;

      // Log slow operations
      if (durationMs > 1000) {
        Logger.w('Slow operation detected: $operation took ${durationMs}ms');
      }
    });
  }

  /// Increment a counter metric
  void incrementCounter(String name, [int increment = 1]) {
    synchronized(_metricsLock, () {
      _counterMetrics[name] = (_counterMetrics[name] ?? 0) + increment;
    });
  }

  /// Set a gauge metric to a specific value
  void setGauge(String name, double value) {
    synchronized(_metricsLock, () {
      _gaugeMetrics[name] = value;
    });
  }

  /// Record an operation with timing automatically measured
  Future<T> recordOperation<T>(
      String operation, Future<T> Function() block) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await block();
      final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
      recordTiming(operation, durationMs);
      return result;
    } catch (e) {
      final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
      recordTiming('${operation}_error', durationMs);
      incrementCounter('${operation}_error_count');
      rethrow;
    }
  }

  /// Record a synchronous operation with timing
  T recordOperationSync<T>(String operation, T Function() block) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = block();
      final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
      recordTiming(operation, durationMs);
      return result;
    } catch (e) {
      final durationMs = DateTime.now().millisecondsSinceEpoch - startTime;
      recordTiming('${operation}_error', durationMs);
      incrementCounter('${operation}_error_count');
      rethrow;
    }
  }

  /// Get statistics for a timing metric
  TimingStats getTimingStats(String operation) {
    return synchronized(_metricsLock, () {
      final timings = _timingMetrics[operation] ?? [];
      if (timings.isEmpty) {
        return TimingStats(
          operation: operation,
          count: 0,
          min: 0,
          max: 0,
          mean: 0,
          median: 0,
          p95: 0,
          p99: 0,
        );
      }

      // Sort for percentile calculations
      timings.sort();

      // Calculate statistics
      final count = timings.length;
      final min = timings.first;
      final max = timings.last;

      // Mean
      final sum = timings.fold<int>(0, (sum, time) => sum + time);
      final mean = sum / count;

      // Median (p50)
      final medianIndex = (count / 2).floor();
      final median = timings[medianIndex];

      // 95th percentile
      final p95Index = ((count * 0.95) - 1).round();
      final p95 = timings[math.min(p95Index, count - 1)];

      // 99th percentile
      final p99Index = ((count * 0.99) - 1).round();
      final p99 = timings[math.min(p99Index, count - 1)];

      return TimingStats(
        operation: operation,
        count: count,
        min: min,
        max: max,
        mean: mean,
        median: median,
        p95: p95,
        p99: p99,
      );
    });
  }

  /// Get a snapshot of all timing statistics
  Map<String, TimingStats> getAllTimingStats() {
    return synchronized(_metricsLock, () {
      final Map<String, TimingStats> stats = {};
      for (final operation in _timingMetrics.keys) {
        stats[operation] = getTimingStats(operation);
      }
      return stats;
    });
  }

  /// Get all counter values
  Map<String, int> getAllCounters() {
    return synchronized(_metricsLock, () {
      return Map.from(_counterMetrics);
    });
  }

  /// Get all gauge values
  Map<String, double> getAllGauges() {
    return synchronized(_metricsLock, () {
      return Map.from(_gaugeMetrics);
    });
  }

  /// Get histogram data for an operation
  Map<int, int> getHistogram(String operation) {
    return synchronized(_metricsLock, () {
      return Map.from(_histograms[operation] ?? {});
    });
  }

  /// Reset all metrics
  void reset() {
    synchronized(_metricsLock, () {
      _timingMetrics.clear();
      _counterMetrics.clear();
      _gaugeMetrics.clear();
      _histograms.clear();
    });

    Logger.i('All metrics have been reset');
  }

  /// Dump all metrics to the log for debugging
  void dumpMetricsToLog() {
    Logger.i('===== SDK Performance Metrics =====');

    // Log timing stats
    final timingStats = getAllTimingStats();
    if (timingStats.isNotEmpty) {
      Logger.i('--- Timing Metrics ---');
      for (final entry in timingStats.entries) {
        final stats = entry.value;
        Logger.i('${stats.operation} (${stats.count} samples): '
            'min=${stats.min}ms, mean=${stats.mean.toStringAsFixed(1)}ms, '
            'median=${stats.median}ms, p95=${stats.p95}ms, p99=${stats.p99}ms, max=${stats.max}ms');
      }
    }

    // Log counters
    final counters = getAllCounters();
    if (counters.isNotEmpty) {
      Logger.i('--- Counters ---');
      for (final entry in counters.entries) {
        Logger.i('${entry.key}: ${entry.value}');
      }
    }

    // Log gauges
    final gauges = getAllGauges();
    if (gauges.isNotEmpty) {
      Logger.i('--- Gauges ---');
      for (final entry in gauges.entries) {
        Logger.i('${entry.key}: ${entry.value.toStringAsFixed(2)}');
      }
    }

    Logger.i('===== End of Metrics Dump =====');
  }
}

/// Statistics for timing metrics
class TimingStats {
  final String operation;
  final int count;
  final int min;
  final int max;
  final double mean;
  final int median;
  final int p95;
  final int p99;

  TimingStats({
    required this.operation,
    required this.count,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.p95,
    required this.p99,
  });

  @override
  String toString() {
    return 'TimingStats($operation, count=$count, min=$min, mean=${mean.toStringAsFixed(1)}, '
        'median=$median, p95=$p95, p99=$p99, max=$max)';
  }
}
