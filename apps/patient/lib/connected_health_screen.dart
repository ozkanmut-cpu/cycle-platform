import 'package:flutter/material.dart';

import 'patient_localizations.dart';

enum ConnectedHealthSourceState { available, unavailable }

enum ConnectedHealthMetricState { observed, missing, conflicting }

class ConnectedHealthSourceSummary {
  const ConnectedHealthSourceSummary({
    required this.name,
    required this.state,
  });

  final String name;
  final ConnectedHealthSourceState state;
}

class ConnectedHealthMetricSummary {
  const ConnectedHealthMetricSummary({
    required this.label,
    required this.state,
    this.value,
    this.unit,
    this.sourceLabel,
  });

  final String label;
  final ConnectedHealthMetricState state;
  final Object? value;
  final String? unit;
  final String? sourceLabel;
}

class ConnectedHealthViewModel {
  const ConnectedHealthViewModel({
    this.sources = const <ConnectedHealthSourceSummary>[],
    this.metrics = const <ConnectedHealthMetricSummary>[],
  });

  final List<ConnectedHealthSourceSummary> sources;
  final List<ConnectedHealthMetricSummary> metrics;

  bool get isEmpty => metrics.isEmpty;
}

class ConnectedHealthScreen extends StatelessWidget {
  const ConnectedHealthScreen({
    required this.viewModel,
    super.key,
  });

  final ConnectedHealthViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final strings = PatientLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.connectedHealth)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              strings.connectedHealth,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(strings.connectedHealthHint),
            const SizedBox(height: 24),
            Text(
              strings.healthSources,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...viewModel.sources.map(
              (source) => Card(
                child: ListTile(
                  leading: const Icon(Icons.sync_alt),
                  title: Text(source.name),
                  subtitle: Text(
                    switch (source.state) {
                      ConnectedHealthSourceState.available =>
                        strings.sourceAvailable,
                      ConnectedHealthSourceState.unavailable =>
                        strings.sourceUnavailable,
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.healthMetrics,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (viewModel.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.monitor_heart_outlined),
                      const SizedBox(width: 12),
                      Expanded(child: Text(strings.noConnectedHealthData)),
                    ],
                  ),
                ),
              )
            else
              ...viewModel.metrics.map(
                (metric) => _MetricCard(metric: metric),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ConnectedHealthMetricSummary metric;

  @override
  Widget build(BuildContext context) {
    final strings = PatientLocalizations.of(context);
    final stateText = switch (metric.state) {
      ConnectedHealthMetricState.observed => strings.observedHealthData,
      ConnectedHealthMetricState.missing => strings.missingHealthData,
      ConnectedHealthMetricState.conflicting => strings.conflictingHealthData,
    };
    final displayValue = metric.state == ConnectedHealthMetricState.observed &&
            metric.value != null
        ? '${metric.value}${metric.unit == null ? '' : ' ${metric.unit}'}'
        : stateText;

    return Card(
      child: ListTile(
        leading: Icon(
          switch (metric.state) {
            ConnectedHealthMetricState.observed => Icons.check_circle_outline,
            ConnectedHealthMetricState.missing => Icons.help_outline,
            ConnectedHealthMetricState.conflicting => Icons.warning_amber_outlined,
          },
        ),
        title: Text(metric.label),
        subtitle: Text(
          metric.sourceLabel == null
              ? stateText
              : '$stateText · ${metric.sourceLabel}',
        ),
        trailing: Text(
          displayValue,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
