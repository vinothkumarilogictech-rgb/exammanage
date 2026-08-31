from flask import Blueprint, render_template, request, redirect, url_for, session, jsonify
from apps.models import db, Branch

branches_bp = Blueprint('branches', __name__)


# --- Helpers -----------------------------------------------------------

def _apply_filters(query, search_term, status):
    if search_term:
        like = f"%{search_term}%"
        query = query.filter(
            db.or_(
                Branch.branch_name.ilike(like),
                Branch.region.ilike(like),
                Branch.contact_info.ilike(like),
            )
        )
    if status in ('Active', 'Inactive'):
        query = query.filter(Branch.status == status)
    return query


def _validate_branch_form(form, current_id=None):
    """Returns (cleaned_data, error) — error is None when valid."""
    branch_name = (form.get('branch_name') or '').strip()
    address = (form.get('address') or '').strip()
    contact_info = (form.get('contact_info') or '').strip()
    region = (form.get('region') or '').strip()
    status = form.get('status') or 'Active'
    if status not in ('Active', 'Inactive'):
        status = 'Active'

    if not branch_name:
        return None, 'Branch Name is required.'

    existing = Branch.query.filter(db.func.lower(Branch.branch_name) == branch_name.lower())
    if current_id:
        existing = existing.filter(Branch.id != current_id)
    if existing.first():
        return None, f'A branch named "{branch_name}" already exists. Branch Name must be unique.'

    data = {
        'branch_name': branch_name,
        'address': address or None,
        'contact_info': contact_info or None,
        'region': region or None,
        'status': status,
    }
    return data, None


# --- Branch List / Overview --------------------------------------------

@branches_bp.route('/branches')
def branch_list():
    search_term = (request.args.get('q') or '').strip()
    status = request.args.get('status') or 'All'

    all_branches = Branch.query.all()
    stats = {
        'total': len(all_branches),
        'active': sum(1 for b in all_branches if b.status == 'Active'),
        'inactive': sum(1 for b in all_branches if b.status == 'Inactive'),
    }

    query = _apply_filters(Branch.query, search_term, status)
    branches = query.order_by(Branch.branch_name.asc()).all()

    return render_template(
        'branch_master.html',
        branches=branches,
        stats=stats,
        search_term=search_term,
        status=status,
        msg=request.args.get('msg'),
    )


# --- Add Branch ----------------------------------------------------------

@branches_bp.route('/branches/add', methods=['GET', 'POST'])
def branch_add():
    if request.method == 'POST':
        data, error = _validate_branch_form(request.form)
        if error:
            return render_template('branch_master_form.html', error=error, form_data=request.form)
        branch = Branch(**data)
        db.session.add(branch)
        db.session.commit()
        return redirect(url_for('branches.branch_list', msg=f'Branch "{branch.branch_name}" added successfully.'))

    return render_template('branch_master_form.html')


# --- Edit Branch -----------------------------------------------------------

@branches_bp.route('/branches/<int:branch_id>/edit', methods=['GET', 'POST'])
def branch_edit(branch_id):
    branch = Branch.query.get_or_404(branch_id)

    if request.method == 'POST':
        data, error = _validate_branch_form(request.form, current_id=branch.id)
        if error:
            return render_template('branch_master_form.html', branch=branch, error=error, form_data=request.form)
        for key, value in data.items():
            setattr(branch, key, value)
        db.session.commit()
        return redirect(url_for('branches.branch_list', msg=f'Branch "{branch.branch_name}" updated successfully.'))

    return render_template('branch_master_form.html', branch=branch)


# --- Deactivate / Activate --------------------------------------------------

@branches_bp.route('/branches/<int:branch_id>/deactivate', methods=['POST'])
def branch_deactivate(branch_id):
    branch = Branch.query.get_or_404(branch_id)
    branch.status = 'Inactive'
    db.session.commit()
    return redirect(url_for('branches.branch_list', msg=f'Branch "{branch.branch_name}" deactivated.'))


@branches_bp.route('/branches/<int:branch_id>/activate', methods=['POST'])
def branch_activate(branch_id):
    branch = Branch.query.get_or_404(branch_id)
    branch.status = 'Active'
    db.session.commit()
    return redirect(url_for('branches.branch_list', msg=f'Branch "{branch.branch_name}" activated.'))


# --- Branch Details ----------------------------------------------------------

@branches_bp.route('/branches/<int:branch_id>')
def branch_detail(branch_id):
    branch = Branch.query.get_or_404(branch_id)
    return render_template('branch_detail.html', branch=branch)


# --- Search (AJAX/JSON) -------------------------------------------------------

@branches_bp.route('/branches/search')
def branch_search():
    search_term = (request.args.get('q') or '').strip()
    status = request.args.get('status') or 'All'
    query = _apply_filters(Branch.query, search_term, status)
    branches = query.order_by(Branch.branch_name.asc()).all()
    return jsonify({
        'results': [
            {
                'id': b.id,
                'branch_name': b.branch_name,
                'region': b.region,
                'contact_info': b.contact_info,
                'status': b.status,
            }
            for b in branches
        ]
    })


# --- Branch Comparison --------------------------------------------------------

@branches_bp.route('/branches/compare')
def branch_compare():
    all_branches = Branch.query.order_by(Branch.branch_name.asc()).all()

    # Support both repeated checkbox params (?ids=1&ids=2) and a
    # comma-separated query string (?ids=1,2) for flexibility.
    raw_ids = request.args.getlist('ids')
    if len(raw_ids) == 1 and ',' in raw_ids[0]:
        raw_ids = raw_ids[0].split(',')
    selected_ids = [int(i) for i in raw_ids if str(i).strip().isdigit()]
    selected_branches = [b for b in all_branches if b.id in selected_ids] if selected_ids else []

    return render_template(
        'branch_compare.html',
        all_branches=all_branches,
        selected_branches=selected_branches,
        selected_ids=selected_ids,
    )


# --- Branch Switcher -----------------------------------------------------------

@branches_bp.route('/branches/switch', methods=['POST'])
def branch_switch():
    branch_id = request.form.get('branch_id', '')
    if branch_id and branch_id.isdigit() and Branch.query.get(int(branch_id)):
        session['active_branch_id'] = int(branch_id)
        session['active_branch_name'] = Branch.query.get(int(branch_id)).branch_name
    else:
        session.pop('active_branch_id', None)
        session.pop('active_branch_name', None)

    next_url = request.form.get('next') or url_for('dashboard_page')
    return redirect(next_url)


@branches_bp.app_context_processor
def inject_branch_switcher():
    """Makes the branch list + selected branch available to every template
    (used by the header Branch Switcher in base.html)."""
    try:
        switcher_branches = Branch.query.order_by(Branch.branch_name.asc()).all()
    except Exception:
        switcher_branches = []
    return {
        'switcher_branches': switcher_branches,
        'active_branch_id': session.get('active_branch_id'),
        'active_branch_name': session.get('active_branch_name', 'All Branches'),
    }
