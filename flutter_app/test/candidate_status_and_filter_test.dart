import 'package:flutter_test/flutter_test.dart';
import 'package:office_management_mobile/models.dart';

void main() {
  group('Candidate Status and Filtering Tests', () {
    test('Candidate model correctly parses Completed status and team fields', () {
      final map = {
        'id': 101,
        'name': 'Alice Wonder',
        'email': 'alice@test.com',
        'status': 'Completed',
        'exam_date': '2026-10-24',
        'team_id': 5,
        'team_name': 'Team Alpha',
        'branch_id': 12,
        'branch_name': 'coimbator',
      };

      final candidate = Candidate.fromMap(map);
      expect(candidate.id, 101);
      expect(candidate.status, 'Completed');
      expect(candidate.teamId, 5);
      expect(candidate.teamName, 'Team Alpha');
      expect(candidate.date, '2026-10-24');
    });

    test('Filtering candidate records by team, date range, and status', () {
      final candidates = [
        Candidate.fromMap({
          'id': 1,
          'name': 'Cand 1',
          'exam_date': '2026-10-20',
          'status': 'Completed',
          'team_id': 5,
          'team_name': 'Team Alpha',
        }),
        Candidate.fromMap({
          'id': 2,
          'name': 'Cand 2',
          'exam_date': '2026-10-22',
          'status': 'Registered',
          'team_id': 5,
          'team_name': 'Team Alpha',
        }),
        Candidate.fromMap({
          'id': 3,
          'name': 'Cand 3',
          'exam_date': '2026-10-24',
          'status': 'Not Completed',
          'team_id': 6,
          'team_name': 'Team Beta',
        }),
        Candidate.fromMap({
          'id': 4,
          'name': 'Cand 4',
          'exam_date': '2026-10-25',
          'status': 'Rescheduled',
          'team_id': null,
          'team_name': '',
        }),
      ];

      // 1. Filter by specific team (Team 5)
      final team5Cands = candidates.where((c) => c.teamId == 5).toList();
      expect(team5Cands.length, 2);

      // 2. Filter unassigned candidates
      final unassigned = candidates.where((c) => c.teamId == null || c.teamId! <= 0).toList();
      expect(unassigned.length, 1);
      expect(unassigned.first.id, 4);

      // 3. Filter by date range (2026-10-20 to 2026-10-22 inclusive)
      final start = DateTime(2026, 10, 20);
      final end = DateTime(2026, 10, 22, 23, 59, 59);
      final dateFiltered = candidates.where((c) {
        final d = DateTime.tryParse(c.date);
        if (d == null) return false;
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
      expect(dateFiltered.length, 2);
      expect(dateFiltered.map((c) => c.id).toSet(), {1, 2});

      // 4. Filter by status 'Completed'
      final completed = candidates.where((c) => c.status == 'Completed').toList();
      expect(completed.length, 1);
      expect(completed.first.name, 'Cand 1');

      // 5. Combined filter: Team 5 AND status 'Completed'
      final combined = candidates.where((c) => c.teamId == 5 && c.status == 'Completed').toList();
      expect(combined.length, 1);
      expect(combined.first.id, 1);
    });

    test('ExamTeam model correctly stores branchId and branchName', () {
      final team = ExamTeam.fromMap({
        'id': 7,
        'name': 'Support Team',
        'exam_type_id': 2,
        'exam_type_name': 'Certified Tester',
        'branch_id': 10,
        'branch_name': 'Pondicherry',
        'status': 'Active',
      });

      expect(team.id, 7);
      expect(team.name, 'Support Team');
      expect(team.branchId, 10);
      expect(team.branchName, 'Pondicherry');
    });
  });
}
