import pytest
import datetime
from app import app, db
from apps.models import Candidate, ExamTeam, ExamType, Branch

def test_team_and_candidate_features():
    with app.app_context():
        # 1. Ensure test branch exists
        branch = Branch.query.first()
        branch_id = branch.id if branch else 1

        # 2. Ensure test exam type exists
        exam_type = ExamType.query.first()
        if not exam_type:
            exam_type = ExamType(name="Test Exam Cert", fee=100.0)
            db.session.add(exam_type)
            db.session.commit()

        # 3. Create or find test team
        team = ExamTeam.query.filter_by(name="Test Quality Team").first()
        if not team:
            team = ExamTeam(name="Test Quality Team", exam_type_id=exam_type.id, branch_id=branch_id)
            db.session.add(team)
            db.session.commit()

        client = app.test_client()

        # Login to obtain Bearer token
        login_res = client.post('/api/v1/auth/login/', json={'username': 'admin', 'password': '1234'})
        assert login_res.status_code == 200
        token = login_res.get_json()['data']['tokens']['access']
        headers = {'Authorization': f'Bearer {token}'}

        # 4. Test GET /api/v1/exams/teams/ returns team
        res = client.get(f'/api/v1/exams/teams/?branch_id={branch_id}', headers=headers)
        assert res.status_code == 200
        teams_data = res.get_json()['data']
        assert any(t['name'] == "Test Quality Team" for t in teams_data)

        # 5. Test Candidate Creation with 'Completed' Status
        today_str = datetime.date.today().strftime('%Y-%m-%d')
        cand_payload = {
            "name": "Jane Test Completed",
            "email": "jane_comp@test.com",
            "phone": "9876543210",
            "branch_id": branch_id,
            "exam_type_id": exam_type.id,
            "team_id": team.id,
            "date": today_str,
            "status": "Completed",
            "remarks": "Passed with distinction"
        }
        res = client.post('/api/v1/exams/candidates/', json=cand_payload, headers=headers)
        assert res.status_code in [200, 201]
        created = res.get_json()['data']
        assert created['status'] == 'Completed'
        assert created['team_id'] == team.id
        cand_id = created['id']

        # 6. Retrieve candidate details
        res = client.get(f'/api/v1/exams/candidates/{cand_id}/', headers=headers)
        assert res.status_code == 200
        cand_details = res.get_json()['data']
        assert cand_details['status'] == 'Completed'
        assert cand_details['team_id'] == team.id
        assert cand_details['team_name'] == team.name

        # 7. Test Candidate Filtering by Team ID
        res = client.get(f'/api/v1/exams/candidates/?team_id={team.id}', headers=headers)
        assert res.status_code == 200
        team_cands = res.get_json()['data']
        assert any(c['id'] == cand_id for c in team_cands)

        # 8. Test Candidate Filtering by Date Range
        res = client.get(f'/api/v1/exams/candidates/?date_from={today_str}&date_to={today_str}', headers=headers)
        assert res.status_code == 200
        date_cands = res.get_json()['data']
        assert any(c['id'] == cand_id for c in date_cands)

        # 9. Test Candidate Filtering by Status
        res = client.get('/api/v1/exams/candidates/?status=Completed', headers=headers)
        assert res.status_code == 200
        comp_cands = res.get_json()['data']
        assert any(c['id'] == cand_id for c in comp_cands)

        # 10. Test Team Report Endpoint
        res = client.get(f'/api/v1/exams/teams/{team.id}/report/?start_date={today_str}&end_date={today_str}&status=Completed', headers=headers)
        assert res.status_code == 200
        rep_data = res.get_json()['data']
        assert 'team' in rep_data
        assert 'candidate_count' in rep_data
        assert rep_data['candidate_count'] >= 1
        assert any(c['id'] == cand_id for c in rep_data['candidates'])

        # 11. Clean up test candidate
        res = client.delete(f'/api/v1/exams/candidates/{cand_id}/', headers=headers)
        assert res.status_code == 200
