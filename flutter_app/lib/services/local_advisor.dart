import 'dart:math';

import '../models/models.dart';

class LocalAdvisor {
  List<Insight> analyze(Room room, List<SensorPoint> history) {
    final t = _values(room.id, SensorType.temperature, history);
    final h = _values(room.id, SensorType.humidity, history);
    final n = _values(room.id, SensorType.noise, history);
    final out = <Insight>[];
    final now = DateTime.now();

    if (t.isNotEmpty) {
      final latest = t.last;
      final slope = _slope(
        t.length > 12 ? t.sublist(t.length - 12) : t,
      );

      if (latest > 28) {
        out.add(
          Insight(
            roomId: room.id,
            title: 'Temperature needs attention',
            body:
                'The latest temperature is ${latest.toStringAsFixed(1)}°C and remains above the preferred operating range.',
            severity: latest > 30 ? Severity.critical : Severity.warning,
            createdAt: now,
            recommendations: const [
              'Check ventilation or cooling.',
              'Review the recent occupancy/activity pattern.',
            ],
          ),
        );
      } else if (slope > .08) {
        out.add(
          Insight(
            roomId: room.id,
            title: 'Temperature is rising',
            body: 'A persistent upward trend is visible in the latest samples.',
            severity: Severity.info,
            createdAt: now,
            recommendations: const [
              'Monitor the next readings.',
              'Check whether room activity has increased.',
            ],
          ),
        );
      }
    }

    if (h.isNotEmpty && h.last > 65) {
      out.add(
        Insight(
          roomId: room.id,
          title: 'High relative humidity',
          body: 'Humidity is currently ${h.last.toStringAsFixed(0)}%.',
          severity: h.last > 75 ? Severity.critical : Severity.warning,
          createdAt: now,
          recommendations: const [
            'Increase ventilation if appropriate.',
            'Check for persistent moisture sources.',
          ],
        ),
      );
    }

    if (n.isNotEmpty) {
      final recent = n.length > 8 ? n.sublist(n.length - 8) : n;
      final avg = recent.reduce((a, b) => a + b) / recent.length;

      if (avg > 650) {
        out.add(
          Insight(
            roomId: room.id,
            title: 'Elevated noise activity',
            body:
                'Recent noise activity is higher than the preferred room profile (average ${avg.toStringAsFixed(0)}).',
            severity: avg > 800 ? Severity.critical : Severity.warning,
            createdAt: now,
            recommendations: const [
              'Check the activity source.',
              'Compare with the same time period on previous days.',
            ],
          ),
        );
      }
    }

    if (out.isEmpty) {
      out.add(
        Insight(
          roomId: room.id,
          title: 'Conditions are stable',
          body: 'No significant issue is visible in the latest sensor history.',
          severity: Severity.info,
          createdAt: now,
          recommendations: const ['Continue monitoring.'],
        ),
      );
    }

    return out;
  }

  bool canAnswer(String question) {
    final q = _normalize(question);

    return [
      'θερμο',
      'temperature',
      'ζεστ',
      'κρυο',
      'υγρα',
      'humidity',
      'θορ',
      'noise',
      'κινησ',
      'motion',
      'sensor',
      'αισθητ',
      'μετρησ',
      'telemetry',
      'score',
      'health',
      'status',
      'προβλημ',
      'προσεξ',
      'καλυτερ',
      'χειροτερ',
      'best',
      'worst',
      'compare',
      'συγκριν',
      'δωματι',
      'room',
      'χωρ',
      'space',
    ].any(q.contains);
  }

  String answer(
    String question,
    List<RoomSnapshot> snapshots,
    List<Insight> insights,
  ) {
    if (snapshots.isEmpty) {
      return 'Δεν υπάρχουν ακόμη δεδομένα χώρων για ανάλυση.';
    }

    final q = _normalize(question);
    final ranked = [...snapshots]
      ..sort((a, b) => a.score.compareTo(b.score));

    final worst = ranked.first;
    final best = ranked.last;
    final hottest = snapshots.reduce(
      (a, b) => a.temperature > b.temperature ? a : b,
    );
    final coolest = snapshots.reduce(
      (a, b) => a.temperature < b.temperature ? a : b,
    );
    final humid = snapshots.reduce(
      (a, b) => a.humidity > b.humidity ? a : b,
    );
    final noisy = snapshots.reduce(
      (a, b) => a.noise > b.noise ? a : b,
    );

    if (_hasAny(q, ['καλυτερ', 'best', 'healthy', 'πιο καλο'])) {
      return 'Ο χώρος με την καλύτερη τρέχουσα εικόνα είναι το ${best.room.name} '
          'με environmental score ${best.score}/100 (${best.statusText}).';
    }

    if (_hasAny(q, ['χειροτερ', 'worst', 'προβλημ', 'προσεξ', 'priority'])) {
      return _priorityAnswer(worst, insights);
    }

    if (_hasAny(q, ['συγκριν', 'compare'])) {
      final ordered = [...snapshots]
        ..sort((a, b) => b.score.compareTo(a.score));
      final lines = ordered.take(5).map(
            (item) =>
                '• ${item.room.name}: ${item.score}/100, ${item.temperature.toStringAsFixed(1)}°C, ${item.humidity.toStringAsFixed(0)}%',
          );

      return 'Σύγκριση των χώρων με βάση την τρέχουσα εικόνα:\n${lines.join('\n')}';
    }

    if (_hasAny(q, ['θερμο', 'temperature', 'ζεστ', 'κρυο'])) {
      if (_hasAny(q, ['κρυο', 'χαμηλ', 'cool', 'cold'])) {
        return 'Η χαμηλότερη θερμοκρασία εμφανίζεται στο ${coolest.room.name}: '
            '${coolest.temperature.toStringAsFixed(1)}°C.';
      }

      return 'Ο θερμότερος χώρος είναι το ${hottest.room.name} με '
          '${hottest.temperature.toStringAsFixed(1)}°C. Αν η τιμή παραμένει '
          'αυξημένη, έλεγξε την τάση των τελευταίων μετρήσεων, τον αερισμό '
          'και την ψύξη του χώρου.';
    }

    if (_hasAny(q, ['υγρα', 'humidity'])) {
      return 'Η υψηλότερη υγρασία εμφανίζεται στο ${humid.room.name}: '
          '${humid.humidity.toStringAsFixed(0)}%. Αν παραμένει αυξημένη, '
          'έλεγξε αερισμό και πιθανές πηγές υγρασίας.';
    }

    if (_hasAny(q, ['θορ', 'noise'])) {
      return 'Το μεγαλύτερο επίπεδο θορύβου εμφανίζεται στο ${noisy.room.name} '
          '(${noisy.noise.toStringAsFixed(0)}). Σύγκρινέ το με το ιστορικό '
          'του ίδιου χώρου για να δεις αν πρόκειται για επίμονη ανωμαλία.';
    }

    if (_hasAny(q, ['κινησ', 'motion', 'active', 'δραστηριο'])) {
      final activeRooms = snapshots.where((item) => item.motion).toList();

      if (activeRooms.isEmpty) {
        return 'Δεν εμφανίζεται ενεργή κίνηση στα δωμάτια της τρέχουσας εικόνας.';
      }

      return 'Κίνηση ανιχνεύεται αυτή τη στιγμή στα: '
          '${activeRooms.map((item) => item.room.name).join(', ')}.';
    }

    if (_hasAny(q, ['score', 'health', 'status', 'κατασταση'])) {
      final lines = ranked.reversed.take(5).map(
            (item) =>
                '• ${item.room.name}: ${item.score}/100 (${item.statusText})',
          );

      return 'Τρέχουσα κατάσταση χώρων:\n${lines.join('\n')}';
    }

    return _priorityAnswer(worst, insights);
  }

  String _priorityAnswer(
    RoomSnapshot worst,
    List<Insight> insights,
  ) {
    final topInsights = insights
        .where((item) => item.roomId == worst.room.id)
        .take(2)
        .map((item) => '• ${item.title}: ${item.body}')
        .join('\n');

    final insightText = topInsights.isEmpty
        ? '• Χρειάζεται έλεγχος των τελευταίων μετρήσεων.'
        : topInsights;

    return 'Με βάση τα τρέχοντα δεδομένα, το ${worst.room.name} χρειάζεται '
        'τη μεγαλύτερη προσοχή (score ${worst.score}/100).\n\n'
        '$insightText\n\n'
        'Πρόταση: ξεκίνα από αυτόν τον χώρο και σύγκρινε τις τελευταίες '
        '24 ώρες με την προηγούμενη εβδομάδα.';
  }

  bool _hasAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }

  String _normalize(String input) {
    var out = input.toLowerCase().trim();

    const replacements = {
      'ά': 'α',
      'έ': 'ε',
      'ή': 'η',
      'ί': 'ι',
      'ϊ': 'ι',
      'ΐ': 'ι',
      'ό': 'ο',
      'ύ': 'υ',
      'ϋ': 'υ',
      'ΰ': 'υ',
      'ώ': 'ω',
      'ς': 'σ',
    };

    for (final entry in replacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }

    return out;
  }

  List<double> _values(
    String roomId,
    SensorType type,
    List<SensorPoint> history,
  ) {
    final points = history
        .where((p) => p.roomId == roomId && p.type == type)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return points.map((p) => p.value).toList();
  }

  double _slope(List<double> values) {
    if (values.length < 2) {
      return 0;
    }

    final n = values.length.toDouble();
    final sx = List.generate(
      values.length,
      (i) => i.toDouble(),
    ).reduce((a, b) => a + b);
    final sy = values.reduce((a, b) => a + b);

    var sxy = 0.0;
    var sx2 = 0.0;

    for (var i = 0; i < values.length; i++) {
      sxy += i * values[i];
      sx2 += i * i;
    }

    final den = n * sx2 - pow(sx, 2);
    return den == 0 ? 0 : (n * sxy - sx * sy) / den;
  }
}
