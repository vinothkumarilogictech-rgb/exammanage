import os
import unittest
import io
from apps import create_app
from apps.models import db, Candidate, Branch, ExamType, ExamAttempt, ExamTeam, Employee


class TestPassportAndParity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app()
        cls.client = cls.app.test_client()

    def test_01_existing_candidates_intact(self):
        """Verify that existing candidates exist and serialize without errors."""
        with self.app.app_context():
            candidates = Candidate.query.all()
            self.assertGreaterEqual(len(candidates), 6, "Expected at least 6 historical candidates")
            for c in candidates:
                # Check safe properties
                self.assertIsNotNone(c.id)
                self.assertIsNotNone(c.name)
                # Null handling for passport fields
                self.assertTrue(c.passport_number is None or isinstance(c.passport_number, str))
                self.assertTrue(c.address_line_1 is None or isinstance(c.address_line_1, str))
                # Effective helpers
                _ = c.effective_dob
                _ = c.effective_nationality

    def test_02_candidate_detail_page_loads_for_old_record(self):
        """Verify old candidate without passport loads HTML page cleanly without null pointer or template errors."""
        with self.app.app_context():
            c = Candidate.query.first()
            self.assertIsNotNone(c)
            candidate_id = c.id

        res = self.client.get(f'/exams/candidates/{candidate_id}')
        self.assertEqual(res.status_code, 200)
        self.assertIn(b'Candidate Profile', res.data)

    def test_03_scan_passport_endpoint_missing_files(self):
        """Verify scan passport endpoint validates file presence safely."""
        res = self.client.post('/exams/candidates/scan-passport')
        self.assertEqual(res.status_code, 400)
        data = res.get_json()
        self.assertFalse(data.get('success', True))

    def test_04_scan_passport_mock_upload_and_key_handling(self):
        """Verify upload saving and graceful handling of Groq API key."""
        fake_image = (io.BytesIO(b"FAKE_IMAGE_DATA_FRONT"), "front.jpg")
        fake_last = (io.BytesIO(b"FAKE_IMAGE_DATA_LAST"), "last.jpg")
        
        res = self.client.post(
            '/exams/candidates/scan-passport',
            data={'front_page': fake_image, 'last_page': fake_last},
            content_type='multipart/form-data'
        )
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn('data', data)
        pdata = data['data']
        self.assertIn('passport_scan_date', pdata)
        self.assertIn('IST', pdata['passport_scan_date'])
        self.assertTrue(pdata.get('passport_front_image', '').startswith('/static/uploads/passports/'))

    def test_05_create_and_search_candidate_with_passport_R3467069(self):
        """Verify saving and searching candidate with passport number R3467069."""
        with self.app.app_context():
            branch = Branch.query.first()
            exam_type = ExamType.query.first()
            self.assertIsNotNone(branch)
            self.assertIsNotNone(exam_type)

            # Check if test candidate already exists or create new
            existing = Candidate.query.filter_by(passport_number='R3467069').first()
            if not existing:
                cand = Candidate(
                    name="Test Passport Candidate",
                    register_number="REG-PASSPORT-01",
                    branch_id=branch.id,
                    exam_type_id=exam_type.id,
                    exam_date="2026-10-01",
                    status="Scheduled",
                    passport_number="R3467069",
                    passport_full_name="TEST PASSPORT CANDIDATE",
                    passport_dob="1995-05-15",
                    passport_gender="Male",
                    passport_nationality="Indian",
                    passport_issue_date="2020-01-10",
                    passport_expiry_date="2030-01-09",
                    address_line_1="123 Tech Park Road",
                    city="Chennai",
                    state="Tamil Nadu",
                    postal_code="600001",
                    country="India",
                    passport_scan_date="2026-09-24 12:00:00 (IST)"
                )
                db.session.add(cand)
                db.session.commit()

            # Verify searching by passport number in candidates list
            res = self.client.get('/exams/candidates/?q=R3467069')
            self.assertEqual(res.status_code, 200)
            self.assertIn(b'R3467069', res.data)

    def test_06_feature_parity_teams_and_employees(self):
        """Verify Exam Teams and Employees endpoints load successfully."""
        res_teams = self.client.get('/exams/teams/')
        self.assertEqual(res_teams.status_code, 200)
        self.assertIn(b'Exam Teams Management', res_teams.data)

        res_emp = self.client.get('/employees/')
        self.assertEqual(res_emp.status_code, 200)
        self.assertIn(b'Employee Management', res_emp.data)


if __name__ == '__main__':
    unittest.main()
