import os
import re
import json
import base64
import uuid
from datetime import datetime
import pytz
import requests
from werkzeug.utils import secure_filename

# Timezone for scan date (Indian Standard Time)
IST = pytz.timezone('Asia/Kolkata')

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp', 'bmp'}
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB per image


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def get_image_mime(filename):
    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else 'jpeg'
    if ext == 'png':
        return 'image/png'
    elif ext == 'webp':
        return 'image/webp'
    return 'image/jpeg'


def normalize_date(date_str):
    """Normalize date strings like DD/MM/YYYY, DD-MM-YYYY to YYYY-MM-DD."""
    if not date_str or not isinstance(date_str, str):
        return None
    date_str = date_str.strip()
    if not date_str:
        return None

    # Check already YYYY-MM-DD
    if re.match(r'^\d{4}-\d{2}-\d{2}$', date_str):
        return date_str

    # DD/MM/YYYY or DD-MM-YYYY
    m = re.match(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$', date_str)
    if m:
        d, mo, y = m.groups()
        return f"{y}-{int(mo):02d}-{int(d):02d}"

    # DD MMM YYYY (e.g., 15 JAN 2025)
    for fmt in ('%d %b %Y', '%d %B %Y', '%d-%b-%Y', '%d/%b/%Y'):
        try:
            dt = datetime.strptime(date_str, fmt)
            return dt.strftime('%Y-%m-%d')
        except ValueError:
            pass

    return date_str


def save_passport_file(file_storage, upload_folder, prefix='front'):
    """Save an uploaded image file securely and return its relative URL path."""
    if not file_storage or not file_storage.filename:
        return None
    if not allowed_file(file_storage.filename):
        return None

    os.makedirs(upload_folder, exist_ok=True)
    ext = file_storage.filename.rsplit('.', 1)[1].lower()
    unique_filename = f"passport_{prefix}_{uuid.uuid4().hex[:12]}_{int(datetime.utcnow().timestamp())}.{ext}"
    safe_path = os.path.join(upload_folder, unique_filename)
    file_storage.seek(0)
    file_storage.save(safe_path)
    file_storage.seek(0)  # Reset pointer for subsequent reads
    return f"/static/uploads/passports/{unique_filename}"


def extract_passport_data_with_groq(front_file, last_file, upload_folder=None):
    """
    Extract passport biodata and address details from front and last page images using Groq Vision AI.
    
    Adheres strictly to extraction rules:
    - Extract only information visibly present.
    - Never invent missing info.
    - Structured JSON output.
    - Scan date captured separately with IST timezone.
    - Handles rate limits and missing keys gracefully.
    """
    groq_api_key = os.environ.get('GROQ_API_KEY', '').strip()

    # Capture current scan date & time in IST
    scan_date = datetime.now(IST).strftime('%Y-%m-%d %H:%M:%S (IST)')

    # Save images to local upload directory if provided
    front_image_url = None
    last_image_url = None
    if upload_folder:
        try:
            if front_file:
                front_image_url = save_passport_file(front_file, upload_folder, prefix='front')
            if last_file:
                last_image_url = save_passport_file(last_file, upload_folder, prefix='last')
        except Exception as e:
            # Non-blocking image save error
            print(f"Warning: could not save passport image files: {e}")

    # Check API key configuration
    if not groq_api_key or groq_api_key == 'YOUR_NEW_GROQ_API_KEY':
        return {
            'success': False,
            'message': 'Groq API key is not configured in backend/.env. Please configure GROQ_API_KEY to enable AI extraction, or proceed with manual entry.',
            'error_code': 'GROQ_KEY_NOT_CONFIGURED',
            'data': {
                'passport_scan_date': scan_date,
                'passport_front_image': front_image_url,
                'passport_last_image': last_image_url,
            }
        }

    # Encode images to base64
    content_parts = []
    content_parts.append({
        'type': 'text',
        'text': (
            "You are an expert passport data extractor for an official Exam Management System. "
            "Examine the attached passport images:\n"
            "IMAGE 1 is the Passport Front Page (Biodata Page).\n"
            "IMAGE 2 is the Passport Last Page (Address Page).\n\n"
            "STRICT EXTRACTION RULES:\n"
            "1. Extract ONLY information that is clearly and visibly present in the images.\n"
            "2. NEVER invent, fabricate, or guess missing information.\n"
            "3. If any field is missing, unreadable, or blurry, return null for that field.\n"
            "4. Do NOT fabricate an address. Extract only what is visibly printed on the last page.\n"
            "5. Normalize dates to YYYY-MM-DD format whenever identifiable (e.g. 15/08/1995 -> 1995-08-15).\n"
            "6. Output must be a single valid JSON object with EXACTLY the following keys:\n"
            "{\n"
            "  \"full_name\": string or null,\n"
            "  \"passport_number\": string or null,\n"
            "  \"dob\": string (YYYY-MM-DD) or null,\n"
            "  \"gender\": string (\"Male\", \"Female\", \"Other\") or null,\n"
            "  \"nationality\": string or null,\n"
            "  \"issue_date\": string (YYYY-MM-DD) or null,\n"
            "  \"expiry_date\": string (YYYY-MM-DD) or null,\n"
            "  \"address_line_1\": string or null,\n"
            "  \"address_line_2\": string or null,\n"
            "  \"city\": string or null,\n"
            "  \"state\": string or null,\n"
            "  \"postal_code\": string or null,\n"
            "  \"country\": string or null\n"
            "}"
        )
    })

    if front_file:
        front_file.seek(0)
        front_bytes = front_file.read()
        front_file.seek(0)
        front_mime = get_image_mime(getattr(front_file, 'filename', 'front.jpg'))
        front_b64 = base64.b64encode(front_bytes).decode('utf-8')
        content_parts.append({
            'type': 'image_url',
            'image_url': {
                'url': f"data:{front_mime};base64,{front_b64}"
            }
        })

    if last_file:
        last_file.seek(0)
        last_bytes = last_file.read()
        last_file.seek(0)
        last_mime = get_image_mime(getattr(last_file, 'filename', 'last.jpg'))
        last_b64 = base64.b64encode(last_bytes).decode('utf-8')
        content_parts.append({
            'type': 'image_url',
            'image_url': {
                'url': f"data:{last_mime};base64,{last_b64}"
            }
        })

    # Groq vision-capable models (active: qwen/qwen3.8-27b)
    vision_models = ['qwen/qwen3.8-27b']
    headers = {
        'Authorization': f"Bearer {groq_api_key}",
        'Content-Type': 'application/json'
    }

    last_error = None
    for model_name in vision_models:
        payload = {
            'model': model_name,
            'messages': [
                {'role': 'user', 'content': content_parts}
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0.1,
            'max_tokens': 1024
        }

        try:
            resp = requests.post(
                'https://api.groq.com/openai/v1/chat/completions',
                headers=headers,
                json=payload,
                timeout=35
            )

            if resp.status_code == 200:
                result_json = resp.json()
                raw_content = result_json['choices'][0]['message']['content']
                extracted = json.loads(raw_content)

                return {
                    'success': True,
                    'message': 'Passport information successfully extracted.',
                    'model_used': model_name,
                    'data': {
                        'passport_full_name': (extracted.get('full_name') or '').strip() or None,
                        'passport_number': (extracted.get('passport_number') or '').strip() or None,
                        'passport_dob': normalize_date(extracted.get('dob')),
                        'passport_gender': (extracted.get('gender') or '').strip() or None,
                        'passport_nationality': (extracted.get('nationality') or '').strip() or None,
                        'passport_issue_date': normalize_date(extracted.get('issue_date')),
                        'passport_expiry_date': normalize_date(extracted.get('expiry_date')),
                        'address_line_1': (extracted.get('address_line_1') or '').strip() or None,
                        'address_line_2': (extracted.get('address_line_2') or '').strip() or None,
                        'city': (extracted.get('city') or '').strip() or None,
                        'state': (extracted.get('state') or '').strip() or None,
                        'postal_code': (extracted.get('postal_code') or '').strip() or None,
                        'country': (extracted.get('country') or '').strip() or None,
                        'passport_scan_date': scan_date,
                        'passport_front_image': front_image_url,
                        'passport_last_image': last_image_url,
                    }
                }
            elif resp.status_code == 429:
                last_error = 'Groq API rate limit reached. Please try again shortly or enter details manually.'
                continue
            elif resp.status_code == 401:
                return {
                    'success': False,
                    'message': 'Groq API authentication failed. Please verify GROQ_API_KEY in backend/.env.',
                    'error_code': 'INVALID_API_KEY',
                    'data': {
                        'passport_scan_date': scan_date,
                        'passport_front_image': front_image_url,
                        'passport_last_image': last_image_url,
                    }
                }
            else:
                last_error = f"Groq API returned HTTP {resp.status_code}: {resp.text[:200]}"
        except requests.exceptions.Timeout:
            last_error = "Groq API request timed out. Please check network connectivity or enter details manually."
        except Exception as ex:
            last_error = f"AI extraction error: {str(ex)}"

    return {
        'success': False,
        'message': last_error or 'Failed to extract passport details using Groq AI. You may enter details manually.',
        'error_code': 'EXTRACTION_FAILED',
        'data': {
            'passport_scan_date': scan_date,
            'passport_front_image': front_image_url,
            'passport_last_image': last_image_url,
        }
    }
