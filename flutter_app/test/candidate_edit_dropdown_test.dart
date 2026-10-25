import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DropdownButton does not assert when items are safely deduplicated and validated', (tester) async {
    // Simulate candidate with teamId: 6, but available teams only have id 1, 2, 3
    final candidateTeamId = 6;
    final availableTeams = [
      {'id': 1, 'name': 'Team A'},
      {'id': 2, 'name': 'Team B'},
      {'id': 3, 'name': 'Team C'},
    ];

    // Build items with our deduplication and inclusion logic
    final items = <DropdownMenuItem<int>>[];
    final seen = <int>{};

    seen.add(-1);
    items.add(const DropdownMenuItem<int>(
      value: -1,
      child: Text('Not Assigned'),
    ));

    for (final t in availableTeams) {
      final id = t['id'] as int;
      if (seen.add(id)) {
        items.add(DropdownMenuItem<int>(
          value: id,
          child: Text(t['name'] as String),
        ));
      }
    }

    // Candidate has teamId 6, which was not in availableTeams:
    if (seen.add(candidateTeamId)) {
      items.add(DropdownMenuItem<int>(
        value: candidateTeamId,
        child: Text('Assigned Team (ID #$candidateTeamId)'),
      ));
    }

    final effectiveValue = seen.contains(candidateTeamId) ? candidateTeamId : -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DropdownButton<int>(
              value: effectiveValue,
              items: items,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Assigned Team (ID #6)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DropdownButton safely falls back to -1 or null when value is unknown and not in items', (tester) async {
    final items = <DropdownMenuItem<int>>[
      const DropdownMenuItem<int>(value: -1, child: Text('Not Assigned')),
      const DropdownMenuItem<int>(value: 1, child: Text('Team 1')),
      const DropdownMenuItem<int>(value: 2, child: Text('Team 2')),
    ];

    final invalidValue = 999;
    final effectiveValue = items.any((it) => it.value == invalidValue) ? invalidValue : -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DropdownButton<int>(
              value: effectiveValue,
              items: items,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Not Assigned'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
