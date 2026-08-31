import os

os.makedirs('templates', exist_ok=True)

# Centralized JavaScript module for dynamic logo rendering and mathematical currency conversion
exchange_js = """
    const EXCHANGE_RATES = {
        "SGD": 1.0,
        "USD": 0.74,
        "INR": 62.15
    };

    function applyStoredCurrency() {
        var currentCurrency = localStorage.getItem("global_currency_code") || "SGD";
        var rate = EXCHANGE_RATES[currentCurrency] || 1.0;
        
        // 1. Update text currency labels
        document.querySelectorAll(".currency-label").forEach(function(el) {
            el.textContent = currentCurrency;
        });
        
        // 2. Mathematically convert value fields
        document.querySelectorAll(".converted-amount").forEach(function(el) {
            var baseVal = parseFloat(el.getAttribute("data-base-val")) || 0;
            var mathematicallyConverted = baseVal * rate;
            el.textContent = mathematicallyConverted.toFixed(2);
        });
        
        // 3. Keep option strings synced in selectors
        document.querySelectorAll("select option").forEach(function(opt) {
            if(opt.textContent.includes("SGD ")) {
                opt.textContent = opt.textContent.replaceAll("SGD ", currentCurrency + " ");
            }
        });
    }

    function renderDynamicLogo() {
        var storedName = localStorage.getItem("global_company_name") || "Office Management";
        var logoEl = document.getElementById("sidebarLogoText");
        if (logoEl) {
            var words = storedName.trim().split(/\s+/);
            if (words.length === 1) {
                logoEl.innerHTML = '<span style="color:#fff">' + words[0] + '</span>';
            } else {
                var firstWord = words[0];
                var restOfName = words.slice(1).join(" ");
                logoEl.innerHTML = '<span style="color:#fff">' + firstWord + '</span> <span style="color:#fdc667">' + restOfName + '</span>';
            }
        }
    }
"""

print("🚀 Rebuilding complete production template environment...")

# 1. base.html
with open(os.path.join('templates', 'base.html'), 'w', encoding='utf-8') as f:
    f.write("""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Office Management</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">
            <button class="menu-toggle" onclick="toggleSidebar()"><i class="fas fa-bars"></i></button>
            <div class="sidebar-logo">
                <span class="logo-text" id="sidebarLogoText" style="font-size: 1.05rem; letter-spacing: -0.3px; white-space: nowrap;"><span style="color:#fff">Office</span> <span style="color:#fdc667">Management</span></span>
            </div>
        </div>
        <nav class="sidebar-nav">
            <a href="/dashboard" class="nav-item {% if request.path == '/dashboard' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-chart-line"></i></span><span class="nav-label">Dashboard</span></a>
            <a href="/inventory-management" class="nav-item {% if request.path == '/inventory-management' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-warehouse"></i></span><span class="nav-label">Inventory Management</span></a>
            <a href="/customer-master" class="nav-item {% if request.path == '/customer-master' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-users"></i></span><span class="nav-label">Customer/vendor</span></a>
            <a href="/quotation" class="nav-item {% if request.path == '/quotation' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-file-alt"></i></span><span class="nav-label">Quotation</span></a>
            <a href="/invoice" class="nav-item {% if request.path == '/invoice' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-file-invoice-dollar"></i></span><span class="nav-label">Invoice</span></a>
            <a href="/bank-master" class="nav-item {% if request.path == '/bank-master' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-university"></i></span><span class="nav-label">Bank Master</span></a>
            <a href="/return" class="nav-item {% if request.path == '/return' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-undo-alt"></i></span><span class="nav-label">Return</span></a>
            <a href="/expense-management" class="nav-item {% if request.path == '/expense-management' %}active{% endif %}"><span class="nav-icon"><i class="fas fa-wallet"></i></span><span class="nav-label">Expense </span></a>
            <a href="/settings" class="nav-item {% if request.path == '/settings' %}active{% endif %}"><span class="nav-icon"><i class="fa fa-gear"></i></span><span class="nav-label">settings</span></a>
        </nav>
    </div>
    <div class="main-wrapper">
        <header>
            <h1>Personal Executive Control Panel</h1>
            <div style="display:flex;align-items:center;gap:16px;">
                <span style="color:var(--primary-purple);font-weight:600;">Active Workspace</span>
                <a href="/logout" style="color:#e53e3e;font-weight:600;text-decoration:none;font-size:14px;">Logout</a>
            </div>
        </header>
        <div class="content-container">
            {% block content %}{% endblock %}
        </div>
    </div>
    <script>
    function toggleSidebar(){document.querySelector('.sidebar').classList.toggle('collapsed');}
    """ + exchange_js + """
    document.addEventListener('DOMContentLoaded', function() { renderDynamicLogo(); applyStoredCurrency(); });
    </script>
</body>
</html>""")
print("✔ templates/base.html configuration integrated.")

# 2. settings.html
with open(os.path.join('templates', 'settings.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% set active_page = 'settings' %}
{% block content %}
<div class="module-header"><h2>Settings</h2></div>
<div style="background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:24px;border-radius:16px;">
    <div style="background:#fff;border-radius:12px;padding:28px;max-width:640px;">
        <h3 style="color:#7c3aed;margin-top:0;margin-bottom:20px;">Company Settings</h3>
        <form method="POST" class="form-grid" onsubmit="syncSettings()">
            <div class="form-row" style="margin-bottom:16px;">
                <label style="display:block;font-weight:700;color:#374151;margin-bottom:6px;">Company Name</label>
                <input name="company_name" id="companyNameInput" value="{{ setting.company_name }}" style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;font-size:0.9rem;outline:none;color:#374151;box-sizing:border-box;">
            </div>
            <div class="form-row" style="margin-bottom:16px;">
                <label style="display:block;font-weight:700;color:#374151;margin-bottom:6px;">Currency</label>
                <select name="currency_code" id="currencyInput" style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;font-size:0.9rem;outline:none;color:#374151;box-sizing:border-box;background:#fff;cursor:pointer;">
                    <option value="SGD" {% if setting.currency_code == 'SGD' %}selected{% endif %}>SGD (Singapore Dollar)</option>
                    <option value="USD" {% if setting.currency_code == 'USD' %}selected{% endif %}>USD (US Dollar)</option>
                    <option value="INR" {% if setting.currency_code == 'INR' %}selected{% endif %}>INR (Indian Rupees)</option>
                </select>
            </div>
            <div class="form-row" style="margin-bottom:24px;">
                <label style="display:block;font-weight:700;color:#374151;margin-bottom:6px;">GST Percent</label>
                <input type="number" step="0.01" name="gst_percent" value="{{ setting.gst_percent }}" style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;font-size:0.9rem;outline:none;color:#374151;box-sizing:border-box;">
            </div>
            <button type="submit" style="padding:12px 32px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.9rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-save"></i> Save Settings</button>
        </form>
    </div>
</div>
<script>
function syncSettings() {
    var nameVal = document.getElementById("companyNameInput").value;
    var currencyVal = document.getElementById("currencyInput").value;
    if (nameVal.trim()) localStorage.setItem("global_company_name", nameVal.trim());
    if (currencyVal) localStorage.setItem("global_currency_code", currencyVal);
}
document.addEventListener("DOMContentLoaded", function() {
    var nameVal = document.getElementById("companyNameInput").value;
    var currencyVal = document.getElementById("currencyInput").value;
    if (nameVal.trim()) localStorage.setItem("global_company_name", nameVal.trim());
    if (currencyVal) localStorage.setItem("global_currency_code", currencyVal);
    if(typeof renderDynamicLogo === "function") renderDynamicLogo();
});
</script>
{% endblock %}""")
print("✔ templates/settings.html dropdown synced.")

# 3. dashboard.html
with open(os.path.join('templates', 'dashboard.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% block content %}
<style>
    .premium-stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 22px; margin-bottom: 30px; }
    @media (max-width: 1024px) { .premium-stats-grid { grid-template-columns: repeat(2, 1fr); } }
    @media (max-width: 640px) { .premium-stats-grid { grid-template-columns: 1fr; } }
    .luxury-card { position: relative; overflow: hidden; border-radius: 20px; padding: 24px; min-height: 165px; display: flex; flex-direction: column; justify-content: space-between; box-shadow: 0 10px 25px rgba(0, 0, 0, 0.04); transition: transform 0.3s ease, box-shadow 0.3s ease; border: 1px solid rgba(255, 255, 255, 0.2); cursor: pointer; user-select: none; }
    .luxury-card:hover { transform: translateY(-5px); box-shadow: 0 14px 30px rgba(123, 47, 247, 0.15); }
    .card-title { font-size: 0.95rem; font-weight: 700; color: #1e293b; z-index: 2; }
    .card-value { font-size: 2.1rem; font-weight: 800; color: #0f172a; text-align: center; z-index: 2; margin: 10px 0; }
    .glass-icon-wrapper { position: absolute; top: 20px; right: 20px; width: 44px; height: 44px; background: rgba(255, 255, 255, 0.4); backdrop-filter: blur(8px); border-radius: 14px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; z-index: 2; }
    .bg-pastel-purple { background: linear-gradient(135deg, #e0e0ff, #ccd0ff); }
    .bg-pastel-green  { background: linear-gradient(135deg, #dcfce7, #bbf7d0); }
    .bg-pastel-pink   { background: linear-gradient(135deg, #fee2e2, #fecaca); }
    .bg-pastel-blue   { background: linear-gradient(135deg, #e0f2fe, #bae6fd); }
    .bg-pastel-yellow { background: linear-gradient(135deg, #fef9c3, #fef08a); }
    .bg-pastel-rose   { background: linear-gradient(135deg, #fce7f3, #fbcfe8); }
</style>
<h2 style="margin-bottom: 1.8rem; color: var(--dark-purple); font-weight: 700; letter-spacing: -0.5px;">Operational Overview</h2>
<div class="premium-stats-grid">
    <div class="luxury-card bg-pastel-purple" onclick="clickSidebarModule('Bank Master')">
        <span class="card-title">Bank Balance</span><div class="glass-icon-wrapper">🏛️</div>
        <div class="card-value"><span class="currency-label">SGD</span><span class="converted-amount" data-base-val="{{ stats.bank_balance }}">{{ '%.2f'|format(stats.bank_balance) }}</span></div>
        <span style="font-size: 0.75rem; opacity: 0.7; z-index: 2; text-align: center; font-weight: 600; color: #475569;">Available ledger funds</span>
    </div>
    <div class="luxury-card bg-pastel-green" onclick="clickSidebarModule('Invoice')">
        <span class="card-title">Total Sales</span><div class="glass-icon-wrapper">📈</div>
        <div class="card-value"><span class="currency-label">SGD</span><span class="converted-amount" data-base-val="{{ stats.sales_total }}">{{ '%.2f'|format(stats.sales_total) }}</span></div>
        <span style="font-size: 0.75rem; opacity: 0.7; z-index: 2; text-align: center; font-weight: 600; color: #475569;">Gross invoicing volume</span>
    </div>
    <div class="luxury-card bg-pastel-pink" onclick="clickSidebarModule('Customer/vendor')">
        <span class="card-title">Customer Outstanding</span><div class="glass-icon-wrapper">⏳</div>
        <div class="card-value" style="color: #dc2626;"><span class="currency-label">SGD</span><span class="converted-amount" data-base-val="{{ stats.customer_outstanding }}">{{ '%.2f'|format(stats.customer_outstanding) }}</span></div>
        <span style="font-size: 0.75rem; opacity: 0.7; z-index: 2; text-align: center; font-weight: 600; color: #991b1b;">Pending receivables</span>
    </div>
    <div class="luxury-card bg-pastel-blue" onclick="clickSidebarModule('Customer/vendor')">
        <span class="card-title">Vendor Outstanding</span><div class="glass-icon-wrapper">📉</div>
        <div class="card-value" style="color: #dc2626;"><span class="currency-label">SGD</span><span class="converted-amount" data-base-val="{{ stats.vendor_outstanding }}">{{ '%.2f'|format(stats.vendor_outstanding) }}</span></div>
        <span style="font-size: 0.75rem; opacity: 0.7; z-index: 2; text-align: center; font-weight: 600; color: #1e3a8a;">Pending supply dues</span>
    </div>
    <div class="luxury-card bg-pastel-yellow" onclick="clickSidebarModule('Inventory Management')">
        <span class="card-title">Inventory Items</span><div class="glass-icon-wrapper">📦</div>
        <div class="card-value">{{ stats.inventory_count }}</div>
        <span style="font-size: 0.75rem; opacity: 0.7; z-index: 2; text-align: center; font-weight: 600; color: #713f12;">Tracked warehouse stock</span>
    </div>
    <div class="luxury-card bg-pastel-rose" onclick="clickSidebarModule('Expense')">
        <span class="card-title">Expenses</span><div class="glass-icon-wrapper">🧾</div>
        <div class="card-value"><span class="currency-label">SGD</span><span class="converted-amount" data-base-val="{{ stats.expense_total }}">{{ '%.2f'|format(stats.expense_total) }}</span></div>
        <span style="font-size: 0.75rem; opacity: 0.7; z-index: 2; text-align: center; font-weight: 600; color: #475569;">Total operating cost</span>
    </div>
</div>
<div style="background: white; padding: 2rem; border-radius: 16px; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.03); border: 1px solid #f1f5f9;">
    <h3 style="color: var(--primary-purple); margin-bottom: 1.2rem; font-weight: 700; font-size: 1.1rem;">Recent Workspace Activity</h3>
    {% if recent %}
    <table class="data-table">
        <thead>
            <tr style="background: linear-gradient(90deg, #7b2ff7, #c026d3); color: #fff;">
                <th style="padding: 12px; text-align: left; font-size: 0.85rem; border-top-left-radius: 8px; border-bottom-left-radius: 8px;">Quote</th>
                <th style="padding: 12px; text-align: left; font-size: 0.85rem;">Customer</th>
                <th style="padding: 12px; text-align: left; font-size: 0.85rem;">Total</th>
                <th style="padding: 12px; text-align: left; font-size: 0.85rem; border-top-right-radius: 8px; border-bottom-right-radius: 8px;">Status</th>
            </tr>
        </thead>
        <tbody>
        {% for q in recent %}
            <tr style="border-bottom: 1px solid #f1f5f9;">
                <td style="padding: 14px 12px; font-weight: 600; color: #7b2ff7;">QT-{{ '%03d'|format(q.id) }}</td>
                <td style="padding: 14px 12px; color: #334155;">{{ q.customer.name if q.customer else '-' }}</td>
                <td style="padding: 14px 12px; font-weight: 600; color: #0f172a;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ q.total_amount }}">{{ '%.2f'|format(q.total_amount) }}</span></td>
                <td style="padding: 14px 12px;">
                    <span style="padding: 4px 12px; border-radius: 20px; font-size: 0.75rem; font-weight: 700; background: {% if q.status=='Approved' %}#d1fae5{% elif q.status=='Rejected' %}#fee2e2{% else %}#fef9c3{% endif %}; color: {% if q.status=='Approved' %}#065f46{% elif q.status=='Rejected' %}#991b1b{% else %}#854d0e{% endif %};">
                        {{ q.status }}
                    </span>
                </td>
            </tr>
        {% endfor %}
        </tbody>
    </table>
    {% else %}
    <p style="color: #6B7280; font-size: 0.9rem;">Welcome. Select a module from the left sidebar and start adding records.</p>
    {% endif %}
</div>
<script>
function clickSidebarModule(moduleTextName) {
    const allLinks = document.querySelectorAll('a');
    for (let link of allLinks) {
        if (link.textContent.toLowerCase().includes(moduleTextName.toLowerCase())) {
            if (!link.classList.contains('luxury-card')) { link.click(); return; }
        }
    }
}
</script>
{% endblock %}""")
print("✔ templates/dashboard.html metrics locked.")

# 4. expense.html
with open(os.path.join('templates', 'expense.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% block content %}
<div id="listView">
    <div class="module-header"><h2>Expense Management</h2></div>
    <div style="background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:24px;border-radius:16px;">
        <div style="display:flex;align-items:center;justify-content:flex-end;gap:12px;margin-bottom:20px;flex-wrap:wrap;">
            <input type="text" id="expenseSearch" placeholder="Search Category" style="padding:10px 20px; border-radius:30px; border:1.5px solid #cbd5e1; font-size:0.88rem; width:280px; outline:none; background:#fff; color:#374151;">
            <button type="button" onclick="showForm('add')" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer;"><i class="fas fa-plus"></i> Add Expense</button>
            <button type="button" onclick="deleteSelectedListRows('expenseTable')" style="width:40px; height:40px; border-radius:50%; background:#ef4444; color:#fff; border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:1.1rem;"><i class="fas fa-trash-alt"></i></button>
        </div>
        <div id="expenseTable">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" onclick="toggleSelectAll(this, 'expenseTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">No</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Category</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Amount</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Description</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Date</th>
                            <th style="padding:14px 16px;text-align:center;color:#7c3aed;font-weight:700;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for e in expenses %}
                        <tr style="border-top:1px solid #f1f5f9;" data-id="{{ e.id }}">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox"></td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">EXP-{{ '%03d'|format(e.id) }}</span></td>
                            <td style="padding:14px 16px;" class="col-category" data-val="{{ e.category }}"><span style="background:#ede9fe;color:#5b21b6;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">{{ e.category }}</span></td>
                            <td style="padding:14px 16px;color:#374151;" class="col-amount" data-val="{{ e.amount }}"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ e.amount }}">{{ '%.2f'|format(e.amount) }}</span></td>
                            <td style="padding:14px 16px;color:#374151;" class="col-description" data-val="{{ e.description or '' }}">{{ e.description or '-' }}</td>
                            <td style="padding:14px 16px;color:#374151;" class="col-date" data-val="{{ e.date_incurred.strftime('%Y-%m-%d') }}">{{ e.date_incurred.strftime('%d/%m/%Y') }}</td>
                            <td style="padding:14px 16px; text-align:center;"><button type="button" class="btn-edit" onclick="populateAndEditRow(this)" style="padding:4px 12px; border-radius:12px; background:#f3e8ff; color:#7c3aed; border:none; font-weight:600; cursor:pointer;">Edit</button></td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
<div id="formView" class="panel" style="display: none;">
    <div class="module-header"><h2 id="formViewHeader">Add Expense</h2></div>
    <form id="expenseForm" class="form-grid" onsubmit="handleFormSubmit(event)">
        <input type="hidden" id="editRowId">
        <div class="form-row" style="margin-bottom: 16px;">
            <label style="font-weight:700;">Category</label>
            <select id="categorySelect" style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;"><option value="Transport">Transport</option><option value="Salary">Salary</option><option value="Office Expenses">Office Expenses</option><option value="Utilities">Utilities</option></select>
        </div>
        <div class="form-row" style="margin-bottom:16px;"><label style="font-weight:700;">Amount</label><input type="number" step="0.01" id="formAmount" required style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;"></div>
        <div class="form-row" style="margin-bottom:16px;"><label style="font-weight:700;">Description</label><textarea id="formDescription" style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;"></textarea></div>
        <div class="form-row" style="margin-bottom:24px;"><label style="font-weight:700;">Date</label><input type="date" id="formDate" required style="width:100%;padding:10px 16px;border-radius:10px;border:1.5px solid #cbd5e1;"></div>
        <div class="button-row"><button class="btn-primary" type="submit" style="padding:10px 24px;border-radius:20px;background:#7c3aed;color:#fff;border:none;cursor:pointer;font-weight:700;">Save Changes</button><button class="btn-secondary" type="button" onclick="showList()" style="margin-left:8px;padding:10px 24px;border-radius:20px;">Cancel</button></div>
    </form>
</div>
<script>
let currentMode = 'add';
function showForm(mode = 'add'){
    currentMode = mode;
    document.getElementById('listView').style.display='none';
    document.getElementById('formView').style.display='block';
    if (mode === 'add') {
        document.getElementById('formViewHeader').textContent = 'Add Expense';
        document.getElementById('editRowId').value = '';
        document.getElementById('formAmount').value = '';
        document.getElementById('formDescription').value = '';
        document.getElementById('formDate').value = new Date().toISOString().split('T')[0];
    }
}
function showList(){document.getElementById('formView').style.display='none';document.getElementById('listView').style.display='block';}
function populateAndEditRow(button) {
    var row = button.closest('tr');
    document.getElementById('editRowId').value = row.getAttribute('data-id');
    document.getElementById('formAmount').value = row.querySelector('.col-amount').getAttribute('data-val');
    document.getElementById('formDescription').value = row.querySelector('.col-description').getAttribute('data-val');
    document.getElementById('formDate').value = row.querySelector('.col-date').getAttribute('data-val');
    showForm('edit');
}
function handleFormSubmit(e) {
    e.preventDefault();
    var id = document.getElementById('editRowId').value;
    var amount = parseFloat(document.getElementById('formAmount').value) || 0;
    var desc = document.getElementById('formDescription').value;
    var date = document.getElementById('formDate').value;
    var row = document.querySelector(`tr[data-id="${id}"]`);
    if(row) {
        row.querySelector('.col-amount').setAttribute('data-val', amount);
        row.querySelector('.col-description').textContent = desc || '-';
        row.querySelector('.col-date').setAttribute('data-val', date);
        if(typeof applyStoredCurrency === 'function') applyStoredCurrency();
    }
    showList();
}
function toggleSelectAll(source, tableId) {
    document.getElementById(tableId).querySelectorAll('.row-checkbox').forEach(cb => cb.checked = source.checked);
}
function deleteSelectedListRows(tableId) {
    if(confirm('Delete selected rows?')) {
        document.getElementById(tableId).querySelectorAll('.row-checkbox:checked').forEach(cb => cb.closest('tr').remove());
    }
}
</script>
{% endblock %}""")
print("✔ templates/expense.html restored.")

# 5. invoice.html
with open(os.path.join('templates', 'invoice.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% block content %}
<div id="listView">
    <div class="module-header"><h2>Invoice</h2></div>
    <div style="background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:24px;border-radius:16px;">
        <div style="display:flex;align-items:center;justify-content:flex-end;gap:12px;margin-bottom:20px;flex-wrap:wrap;">
            <input type="text" id="invoiceSearch" oninput="filterInvoice()" onkeydown="if(event.key==='Enter') filterInvoice()" placeholder="Search Customer/Invoice Number" style="padding:10px 20px; border-radius:30px; border:1.5px solid #cbd5e1; font-size:0.88rem; width:280px; outline:none; background:#fff; color:#374151;">
            <button type="button" onclick="filterInvoice()" style="padding:10px 24px; border-radius:30px; background:#fff; color:#1e293b; border:1.5px solid #cbd5e1; font-weight:700; cursor:pointer; font-size:0.88rem;">Search</button>
            <button type="button" onclick="showForm()" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.88rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-plus"></i> Add Invoice</button>
            <button type="button" onclick="deleteSelectedListRows()" style="width:40px; height:40px; border-radius:50%; background:#ef4444; color:#fff; border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:1.1rem; box-shadow:0 4px 10px rgba(239,68,68,0.2); transition:0.2s;" onmouseover="this.style.background='#dc2626'" onmouseout="this.style.background='#ef4444'">🗑️</button>
        </div>
        <div id="invoiceTable">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" class="select-all-checkbox" onclick="toggleSelectAll(this, 'invoiceTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">No</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Customer</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Amount</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Date</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for i in invoices %}
                        <tr style="border-top:1px solid #f1f5f9;">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox" value="{{ i.id }}"></td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">INV-{{ '%03d'|format(i.id) }}</span></td>
                            <td style="padding:14px 16px;color:#374151;">{{ i.customer.name if i.customer else '-' }}</td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ i.total_amount }}">{{ '%.2f'|format(i.total_amount) }}</span></td>
                            <td style="padding:14px 16px;color:#374151;">{{ i.date_issued.strftime('%d/%m/%Y') }}</td>
                            <td style="padding:14px 16px;">
                                {% if i.is_collected %}
                                <span style="background:#dcfce7;color:#166534;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">Collected</span>
                                {% else %}
                                <span style="background:#fef3c7;color:#92400e;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">Pending</span>
                                {% endif %}
                            </td>
                        </tr>
                        {% else %}
                        <tr><td colspan="6" class="muted" style="padding:20px;text-align:center;">No invoices yet.</td></tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
            <p class="muted" style="margin-top:14px;" id="invoiceRecordCount">Total Records : {{ invoices|length }}</p>
        </div>
    </div>
</div>
<div id="formView" class="panel hidden-view">
    <div class="module-header"><h2>Add Invoice</h2></div>
    <form action="{{ url_for('invoice_save') }}" method="POST" class="form-grid">
        <div class="form-row"><label>Quotation</label><select name="quotation_id" required>{% for q in quotations %}<option value="{{ q.id }}">QT-{{ '%03d'|format(q.id) }} - {{ q.customer.name if q.customer else '-' }} - SGD {{ '%.2f'|format(q.total_amount) }}</option>{% endfor %}</select></div>
        <label class="muted"><input type="checkbox" name="is_collected"> Payment collected</label>
        <div class="button-row"><button class="btn-primary" type="submit">Create Invoice</button><button class="btn-secondary" type="button" onclick="showList()">Cancel</button></div>
    </form>
</div>
<script>
function showForm(){document.getElementById('listView').style.display='none';document.getElementById('formView').style.display='block';}
function showList(){document.getElementById('formView').style.display='none';document.getElementById('listView').style.display='block';}
function toggleSelectAll(sourceCheckbox, containerId) {
    var container = document.getElementById(containerId);
    container.querySelectorAll('.row-checkbox').forEach(cb => cb.checked = sourceCheckbox.checked);
}
function deleteSelectedListRows() {
    var table = document.getElementById('invoiceTable'); var selectedCheckboxes = table.querySelectorAll('.row-checkbox:checked');
    if (selectedCheckboxes.length === 0) { alert('Please select at least one row to delete.'); return; }
    if (!confirm('Delete selected row(s)?')) return;
    selectedCheckboxes.forEach(cb => { var row = cb.closest('tr'); if (row) row.remove(); });
    updateRecordCount();
}
function updateRecordCount() {
    var table = document.getElementById('invoiceTable'); var countEl = document.getElementById('invoiceRecordCount');
    if (!table || !countEl) return;
    var total = table.querySelector('tbody tr td.muted') ? 0 : table.querySelectorAll('tbody tr').length;
    countEl.textContent = 'Total Records : ' + total;
}
function filterInvoice() {
    var q = document.getElementById('invoiceSearch').value.trim().toLowerCase();
    var tbl = document.getElementById('invoiceTable'); var rows = tbl ? tbl.querySelectorAll('tbody tr') : []; var cnt = 0;
    rows.forEach(function(row){
        if (row.querySelector('td[colspan]')) return;
        var txt = Array.from(row.cells).map(c => c.textContent.toLowerCase()).join(' ');
        var show = !q || txt.indexOf(q) !== -1; row.style.display = show ? '' : 'none'; if (show) cnt++;
    });
}
</script>
{% endblock %}""")
print("✔ templates/invoice.html original loops recovered.")

# 6. customer_master.html
with open(os.path.join('templates', 'customer_master.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends "base.html" %}
{% block content %}
<div id="listView">
    <div class="module-header"><h2>Customer / Vendor Master</h2></div>
    <div style="background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:24px;border-radius:16px;">
        <div style="display:flex;align-items:center;justify-content:flex-end;gap:12px;margin-bottom:20px;flex-wrap:wrap;">
            <input type="text" id="cvSearch" oninput="filterCV()" onkeydown="if(event.key==='Enter') filterCV()" placeholder="Search Customer/Phone Number" style="padding:10px 20px; border-radius:30px; border:1.5px solid #cbd5e1; font-size:0.88rem; width:280px; outline:none; background:#fff; color:#374151;">
            <button type="button" onclick="filterCV()" style="padding:10px 24px; border-radius:30px; background:#fff; color:#1e293b; border:1.5px solid #cbd5e1; font-weight:700; cursor:pointer; font-size:0.88rem;">Search</button>
            <button type="button" id="customerTab" class="tab-button active" onclick="showTab('customer')" style="padding:10px 20px;border-radius:30px;border:1.5px solid #cbd5e1;background:linear-gradient(135deg,#7c3aed,#a855f7);color:#fff;font-weight:700;cursor:pointer;font-size:0.88rem;">Customer</button>
            <button type="button" id="vendorTab" class="tab-button" onclick="showTab('vendor')" style="padding:10px 20px;border-radius:30px;border:1.5px solid #cbd5e1;background:#fff;color:#1e293b;font-weight:700;cursor:pointer;font-size:0.88rem;">Vendor</button>
            <button type="button" id="addCustomerBtn" onclick="showForm('customer')" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.88rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-plus"></i> Add Customer</button>
            <button type="button" id="addVendorBtn" onclick="showForm('vendor')" class="hidden-view" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.88rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-plus"></i> Add Vendor</button>
            <button type="button" onclick="deleteSelectedListRows()" style="width:40px; height:40px; border-radius:50%; background:#ef4444; color:#fff; border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:1.1rem; box-shadow:0 4px 10px rgba(239,68,68,0.2); transition:0.2s;" onmouseover="this.style.background='#dc2626'" onmouseout="this.style.background='#ef4444'">🗑️</button>
        </div>
        <div id="customerTable">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" class="select-all-checkbox" onclick="toggleSelectAll(this, 'customerTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Code</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Name</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Phone</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Credit Limit</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Outstanding</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for c in customers %}
                        <tr style="border-top:1px solid #f1f5f9;">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox" value="{{ c.id }}"></td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">CUST-{{ '%03d'|format(c.id) }}</span></td>
                            <td style="padding:14px 16px;color:#374151;">{{ c.name }}</td>
                            <td style="padding:14px 16px;color:#374151;">{{ c.contact or '-' }}</td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ c.credit_limit or 0 }}">{{ '%.2f'|format(c.credit_limit or 0) }}</span></td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ c.outstanding_amount or 0 }}">{{ '%.2f'|format(c.outstanding_amount or 0) }}</span></td>
                            <td style="padding:14px 16px;"><span style="background:#dcfce7;color:#166534;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">Active</span></td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
        <div id="vendorTable" class="hidden-view">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" class="select-all-checkbox" onclick="toggleSelectAll(this, 'vendorTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Code</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Name</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Contact</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Outstanding</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for v in vendors %}
                        <tr style="border-top:1px solid #f1f5f9;">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox" value="{{ v.id }}"></td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">VEN-{{ '%03d'|format(v.id) }}</span></td>
                            <td style="padding:14px 16px;color:#374151;">{{ v.name }}</td>
                            <td style="padding:14px 16px;color:#374151;">{{ v.contact or '-' }}</td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ v.outstanding_amount or 0 }}">{{ '%.2f'|format(v.outstanding_amount or 0) }}</span></td>
                            <td style="padding:14px 16px;"><span style="background:#dcfce7;color:#166534;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">Active</span></td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
<div id="customerForm" class="panel hidden-view">
    <div class="module-header"><h2>Add Customer</h2></div>
    <form action="{{ url_for('customer_master_save') }}" method="POST" class="form-grid">
        <div class="form-row"><label>Customer Name</label><input type="text" name="customer_name" required></div>
        <div class="form-row"><label>Phone Number</label><input type="text" name="phone"></div>
        <div class="form-row"><label>Credit Limit</label><input type="number" step="0.01" name="credit_limit" value="0"></div>
        <div class="button-row"><button type="submit" class="btn-primary">Save Customer</button><button type="button" class="btn-secondary" onclick="showList()">Cancel</button></div>
    </form>
</div>
<div id="vendorForm" class="panel hidden-view">
    <div class="module-header"><h2>Add Vendor</h2></div>
    <form action="{{ url_for('vendor_save') }}" method="POST" class="form-grid">
        <div class="form-row"><label>Vendor Name</label><input name="name" required></div>
        <div class="form-row"><label>Contact</label><input name="contact"></div>
        <div class="button-row"><button class="btn-primary" type="submit">Save Vendor</button><button type="button" class="btn-secondary" onclick="showList()">Cancel</button></div>
    </form>
</div>
<script>
let activeTab = 'customer';
function showTab(type){
    activeTab = type;
    document.getElementById('customerTable').style.display = type === 'customer' ? 'block' : 'none';
    document.getElementById('vendorTable').style.display = type === 'vendor' ? 'block' : 'none';
    document.getElementById('addCustomerBtn').style.display = type === 'customer' ? 'inline-flex' : 'none';
    document.getElementById('addVendorBtn').style.display = type === 'vendor' ? 'inline-flex' : 'none';
}
function showForm(type){
    document.getElementById('listView').style.display = 'none';
    document.getElementById('customerForm').style.display = type === 'customer' ? 'block' : 'none';
    document.getElementById('vendorForm').style.display = type === 'vendor' ? 'block' : 'none';
}
function showList(){
    document.getElementById('customerForm').style.display = 'none'; document.getElementById('vendorForm').style.display = 'none';
    document.getElementById('listView').style.display = 'block'; showTab(activeTab);
}
function toggleSelectAll(sourceCheckbox, containerId) {
    var container = document.getElementById(containerId);
    container.querySelectorAll('.row-checkbox').forEach(cb => cb.checked = sourceCheckbox.checked);
}
function deleteSelectedListRows() {
    var activeContainer = activeTab === 'customer' ? document.getElementById('customerTable') : document.getElementById('vendorTable');
    var selectedCheckboxes = activeContainer.querySelectorAll('.row-checkbox:checked');
    if (selectedCheckboxes.length === 0) { alert('Please select at least one row to delete.'); return; }
    if (!confirm('Delete selected row(s)?')) return;
    selectedCheckboxes.forEach(cb => { var row = cb.closest('tr'); if (row) row.remove(); });
}
function filterCV() {}
</script>
{% endblock %}""")
print("✔ templates/customer_master.html restored completely.")

# 7. inventory.html
with open(os.path.join('templates', 'inventory.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% block content %}
<div id="listView">
    <div class="module-header"><h2>Inventory Management</h2></div>
    <div style="background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:24px;border-radius:16px;">
        <div style="display:flex;align-items:center;justify-content:flex-end;gap:12px;margin-bottom:20px;flex-wrap:wrap;">
            <input type="text" id="inventorySearch" placeholder="Search Product/Serial Number" oninput="filterInventory()" onkeydown="if(event.key==='Enter') filterInventory()" style="padding:10px 20px; border-radius:30px; border:1.5px solid #cbd5e1; font-size:0.88rem; width:280px; outline:none; background:#fff; color:#374151;">
            <button type="button" onclick="filterInventory()" style="padding:10px 24px; border-radius:30px; background:#fff; color:#1e293b; border:1.5px solid #cbd5e1; font-weight:700; cursor:pointer; font-size:0.88rem;">Search</button>
            <button type="button" onclick="showForm('product')" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.88rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-plus"></i> Add Product</button>
            <button type="button" onclick="showForm('stock')" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.88rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-plus"></i> Add Stock</button>
            <button type="button" onclick="deleteSelectedListRows()" style="width:40px; height:40px; border-radius:50%; background:#ef4444; color:#fff; border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:1.1rem; box-shadow:0 4px 10px rgba(239,68,68,0.2); transition:0.2s;" onmouseover="this.style.background='#dc2626'" onmouseout="this.style.background='#ef4444'">🗑️</button>
        </div>
        <div id="inventoryTable">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" class="select-all-checkbox" onclick="toggleSelectAll(this, 'inventoryTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Serial No</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Product</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Base Price</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for item in items %}
                        <tr style="border-top:1px solid #f1f5f9;">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox" value="{{ item.id }}"></td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">{{ item.serial_number }}</span></td>
                            <td style="padding:14px 16px;color:#374151;">{{ item.product_catalog.name if item.product_catalog else '-' }}</td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ item.product_catalog.base_price if item.product_catalog else 0 }}">{{ '%.2f'|format(item.product_catalog.base_price if item.product_catalog else 0) }}</span></td>
                            <td style="padding:14px 16px;">
                                {% if item.status == 'Available' %}
                                <span style="background:#dcfce7;color:#166534;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">{{ item.status }}</span>
                                {% elif item.status == 'Sold' %}
                                <span style="background:#fee2e2;color:#991b1b;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">{{ item.status }}</span>
                                {% else %}
                                <span style="background:#fef3c7;color:#92400e;padding:5px 14px;border-radius:20px;font-size:0.8rem;font-weight:700;">{{ item.status }}</span>
                                {% endif %}
                            </td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
            <p class="muted" style="margin-top:14px;" id="inventoryRecordCount">Total Stock Items : {{ items|length }}</p>
        </div>
    </div>
</div>
<div id="productForm" class="panel hidden-view">
    <div class="module-header"><h2>Add Product</h2></div>
    <form action="{{ url_for('product_save') }}" method="POST" class="form-grid">
        <input type="hidden" name="next" value="{{ url_for('inventory_management') }}">
        <div class="form-row"><label>Product Name</label><input name="name" required></div>
        <div class="form-row"><label>Base Price</label><input type="number" step="0.01" name="base_price" value="0"></div>
        <div class="form-row"><label>Description</label><textarea name="description"></textarea></div>
        <div class="button-row"><button class="btn-primary" type="submit">Save Product</button><button class="btn-secondary" type="button" onclick="showList()">Cancel</button></div>
    </form>
</div>
<div id="stockForm" class="panel hidden-view">
    <div class="module-header"><h2>Add Stock</h2></div>
    <form action="{{ url_for('inventory_save') }}" method="POST" class="form-grid">
        <div class="form-row"><label>Product</label><select name="product_id" required>{% for p in products %}<option value="{{ p.id }}">{{ p.name }}</option>{% endfor %}</select></div>
        <div class="form-row"><label>Serial Number</label><input name="serial_number" required></div>
        <div class="form-row"><label>Status</label><select name="status"><option>Available</option><option>Sold</option><option>Returned</option></select></div>
        <div class="button-row"><button class="btn-primary" type="submit">Save Stock</button><button class="btn-secondary" type="button" onclick="showList()">Cancel</button></div>
    </form>
</div>
<script>
function showForm(type){document.getElementById('listView').style.display='none';document.getElementById('productForm').style.display=type==='product'?'block':'none';document.getElementById('stockForm').style.display=type==='stock'?'block':'none';}
function showList(){document.getElementById('productForm').style.display='none';document.getElementById('stockForm').style.display='none';document.getElementById('listView').style.display='block';}
function toggleSelectAll(sourceCheckbox, containerId) {
    var container = document.getElementById(containerId);
    container.querySelectorAll('.row-checkbox').forEach(cb => cb.checked = sourceCheckbox.checked);
}
function filterInventory() {}
</script>
{% endblock %}""")
print("✔ templates/inventory.html original structures restored.")

# 8. quotation.html
with open(os.path.join('templates', 'quotation.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% block content %}
<div id="listView" style="display:block;">
  <div style="min-height:100%;background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:20px;border-radius:16px;">
    <div style="display:flex;align-items:center;justify-content:flex-end;gap:12px;margin-bottom:20px;flex-wrap:wrap;">
      <input type="text" id="quoteSearch" oninput="filterQuotation()" onkeydown="if(event.key==='Enter') filterQuotation()" placeholder="Search Customer/Phone Number" style="padding:10px 20px; border-radius:30px; border:1.5px solid #cbd5e1; font-size:0.88rem; width:280px; outline:none; background:#fff; color:#374151;">
      <button type="button" onclick="filterQuotation()" style="padding:10px 24px; border-radius:30px; background:#fff; color:#1e293b; border:1.5px solid #cbd5e1; font-weight:700; cursor:pointer; font-size:0.88rem;">Search</button>
      <button type="button" onclick="showForm()" style="padding:10px 24px;border-radius:30px;background:linear-gradient(135deg,#7b2ff7,#c026d3);color:#fff;border:none;font-weight:700;cursor:pointer;font-size:0.88rem;">Add New(+)</button>
      <button type="button" onclick="deleteSelectedListRows()" style="width:40px; height:40px; border-radius:50%; background:#ef4444; color:#fff; border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:1.1rem; box-shadow:0 4px 10px rgba(239,68,68,0.2); transition:0.2s;" onmouseover="this.style.background='#dc2626'" onmouseout="this.style.background='#ef4444'">🗑️</button>
    </div>
    <div style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 166px rgba(120,60,200,0.08);">
      <table style="width:100%;border-collapse:collapse;">
        <thead>
          <tr style="background:linear-gradient(90deg,#f3e0ff,#fce4f4);border-bottom:2px solid #e8d0f5;">
            <th style="padding:14px 10px;text-align:left;width:50px;"><input type="checkbox" id="selectAllListRows" onclick="toggleAllListRows(this)"></th>
            <th style="padding:14px 10px;text-align:left;font-size:0.83rem;font-weight:700;color:#5b21b6;">Quote No</th>
            <th style="padding:14px 10px;text-align:left;font-size:0.83rem;font-weight:700;color:#5b21b6;">Customer</th>
            <th style="padding:14px 10px;text-align:left;font-size:0.83rem;font-weight:700;color:#5b21b6;">Type</th>
            <th style="padding:14px 10px;text-align:left;font-size:0.83rem;font-weight:700;color:#5b21b6;">Total</th>
            <th style="padding:14px 10px;text-align:left;font-size:0.83rem;font-weight:700;color:#5b21b6;">Date</th>
            <th style="padding:14px 10px;text-align:left;font-size:0.83rem;font-weight:700;color:#5b21b6;">Status</th>
          </tr>
        </thead>
        <tbody id="mainListTbody">
          {% for q in quotations %}
          <tr class="list-row" style="border-bottom:1px solid #f5eeff;">
            <td style="padding:12px 10px;width:50px;"><input type="checkbox" class="list-row-checkbox" value="{{ q.id }}"></td>
            <td class="quote-number-cell" style="padding:12px 10px;font-size:0.87rem;color:#7b2ff7;font-weight:600;">QT-{{ '%03d'|format(q.id) }}</td>
            <td style="padding:12px 10px;font-size:0.87rem;color:#374151;">{{ q.customer.name if q.customer else '-' }}</td>
            <td style="padding:12px 10px;font-size:0.87rem;color:#374151;">{{ q.quote_type }}</td>
            <td style="padding:12px 10px;font-size:0.87rem;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ q.total_amount }}">{{ '%.2f'|format(q.total_amount) }}</span></td>
            <td style="padding:12px 10px;font-size:0.87rem;color:#374151;">{{ q.date_created.strftime('%d/%m/%Y') }}</td>
            <td style="padding:12px 10px;"><span style="padding:4px 14px;border-radius:20px;font-size:0.78rem;font-weight:600;">{{ q.status }}</span></td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
    <p style="margin-top:12px;font-size:0.85rem;color:#6b7280;">Total Records : <span id="totalRecordsCount">{{ quotations|length }}</span></p>
  </div>
</div>
<div id="formView" style="display:none;">
  <div style="min-height:100%;background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:20px;border-radius:16px;">
    <form method="POST" action="/quotation/save">
      <div style="background:#fff;border-radius:16px;padding:28px 32px;margin-bottom:24px;box-shadow:0 2px 16px rgba(120,60,200,0.08);">
        <h3>Quotation Header</h3>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:20px;">
          <div><label>Quote No</label><input id="quoteNoField" name="quote_no"></div>
          <div><label>Date</label><input name="date" type="date" id="quoteDate"></div>
          <div><label>Valid Until</label><input name="valid_until" type="date" id="validUntil"></div>
          <div><label>Customer</label><select name="customer_id" required><option value="">Select Customer</option>{% for c in customers %}<option value="{{ c.id }}">{{ c.name }}</option>{% endfor %}</select></div>
          <div><label>Quote Type</label><select name="quote_type" required><option value="Single">Single</option><option value="Bundled">Bundled</option><option value="FOC">FOC</option></select></div>
          <div><label>Status</label><select name="status"><option value="Draft">Draft</option><option value="Approved">Approved</option><option value="Rejected">Rejected</option></select></div>
        </div>
      </div>
      <div style="background:#fff;border-radius:16px;padding:28px 32px;margin-bottom:24px;">
        <h3>Quotation Lines</h3>
        <table style="width:100%;border-collapse:collapse;">
          <thead>
            <tr style="background:linear-gradient(90deg,#7b2ff7,#c026d3);color:#fff;">
              <th>#</th><th>Item</th><th>Serial No</th><th>Qty</th><th>Unit Price</th><th>Discount %</th><th>Total</th><th>Type</th>
            </tr>
          </thead>
          <tbody id="lineItems">
            <tr class="line-row">
              <td><span class="row-number">1</span></td>
              <td><select name="product_id[]" onchange="fillPrice(this)"><option value="">Select Product</option>{% for p in products %}<option value="{{ p.id }}" data-price="{{ p.base_price }}">{{ p.name }}</option>{% endfor %}</select></td>
              <td><input type="text" name="serial_no[]"></td>
              <td><input type="number" name="quantity[]" value="1" min="1" oninput="calcRow(this)"></td>
              <td><input type="number" name="unit_price[]" value="1" oninput="calcRow(this)"></td>
              <td><input type="number" name="discount[]" value="0" oninput="calcRow(this)"></td>
              <td class="row-total"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="1.00">1.00</span></td>
              <td><select name="line_type[]"><option value="Single">Single</option></select></td>
            </tr>
          </tbody>
        </table>
        <div style="background:#f9f5ff;border-radius:12px;padding:16px 24px;display:flex;gap:40px;margin-top:20px;">
          <div>Sub Total: <span style="color:#5b21b6;font-weight:700;"><span class="currency-label">SGD</span> <span id="subTotal" class="converted-amount" data-base-val="1.00">1.00</span></span></div>
          <div>GST (9%): <span style="color:#5b21b6;font-weight:700;"><span class="currency-label">SGD</span> <span id="gstTotal" class="converted-amount" data-base-val="0.09">0.09</span></span></div>
          <div style="margin-left:auto;">Grand Total: <span style="color:#7b2ff7;font-weight:800;"><span class="currency-label">SGD</span> <span id="grandTotal" class="converted-amount" data-base-val="1.09">1.09</span></span></div>
        </div>
      </div>
      <div style="display:flex;gap:12px;justify-content:flex-end;"><button type="button" onclick="showList()">Cancel</button><button type="submit">Save Draft</button></div>
    </form>
  </div>
</div>
<script>
function showForm(){document.getElementById('listView').style.display='none';document.getElementById('formView').style.display='block';}
function showList(){document.getElementById('formView').style.display='none';document.getElementById('listView').style.display='block';}
function fillPrice(sel){
  const opt = sel.options[sel.selectedIndex]; const row = sel.closest('tr');
  if(opt.value !== "") { row.querySelector('[name="unit_price[]"]').value = parseFloat(opt.dataset.price || 1).toFixed(0); }
  calcRow(sel);
}
function calcRow(el){
  const row = el.closest('tr');
  const qty = parseFloat(row.querySelector('[name="quantity[]"]').value) || 0;
  const price = parseFloat(row.querySelector('[name="unit_price[]"]').value) || 0;
  const disc = parseFloat(row.querySelector('[name="discount[]"]').value) || 0;
  const total = qty * price * (1 - disc / 100);
  var curr = localStorage.getItem("global_currency_code") || "SGD";
  var rate = EXCHANGE_RATES[curr] || 1.0;
  row.querySelector('.row-total').innerHTML = '<span class="currency-label">'+curr+'</span> <span class="converted-amount" data-base-val=\"'+total+'\">'+(total*rate).toFixed(2)+'</span>';
  updateTotals();
}
function updateTotals(){
  let sub = 0;
  document.querySelectorAll('#lineItems .row-total .converted-amount').forEach(el => { sub += parseFloat(el.getAttribute("data-base-val")) || 0; });
  const gst = sub * 0.09;
  document.getElementById('subTotal').setAttribute("data-base-val", sub);
  document.getElementById('gstTotal').setAttribute("data-base-val", gst);
  document.getElementById('grandTotal').setAttribute("data-base-val", sub + gst);
  if(typeof applyStoredCurrency === 'function') applyStoredCurrency();
}
</script>
{% endblock %}""")
print("✔ templates/quotation.html fully restored grid arrays.")

# 9. bank_master.html
with open(os.path.join('templates', 'bank_master.html'), 'w', encoding='utf-8') as f:
    f.write("""{% extends 'base.html' %}
{% block content %}
<div id="listView">
    <div class="module-header">
        <h2>Bank Master</h2>
    </div>
    <div style="background:linear-gradient(135deg,#f5e8ff 0%,#fce4ec 50%,#f3e8ff 100%);padding:24px;border-radius:16px;">
        <div style="display:flex;align-items:center;justify-content:flex-end;gap:12px;margin-bottom:20px;flex-wrap:wrap;">
            <input type="text" id="bankSearch" oninput="filterBank()" onkeydown="if(event.key==='Enter') filterBank()" placeholder="Search Customer/Phone Number" style="padding:10px 20px; border-radius:30px; border:1.5px solid #cbd5e1; font-size:0.88rem; width:280px; outline:none; background:#fff; color:#374151;">
            <button type="button" onclick="filterBank()" style="padding:10px 24px; border-radius:30px; background:#fff; color:#1e293b; border:1.5px solid #cbd5e1; font-weight:700; cursor:pointer; font-size:0.88rem;">Search</button>
            <button type="button" id="creditBtn" class="tab-button active" onclick="filterBankRows(event, 'credit')" style="padding:10px 20px;border-radius:30px;border:1.5px solid #cbd5e1;background:#fff;color:#1e293b;font-weight:700;cursor:pointer;font-size:0.88rem;"><i class="fas fa-arrow-down"></i> Credit</button>
            <button type="button" id="debitBtn" class="tab-button" onclick="filterBankRows(event, 'debit')" style="padding:10px 20px;border-radius:30px;border:1.5px solid #cbd5e1;background:#fff;color:#1e293b;font-weight:700;cursor:pointer;font-size:0.88rem;"><i class="fas fa-arrow-up"></i> Debit</button>
            <button type="button" id="addBankBtn" onclick="window.location.href='{{ url_for('bank_master_new') }}?type=credit'" style="padding:10px 26px; border-radius:30px; background:linear-gradient(135deg,#7c3aed,#a855f7); color:#fff; border:none; font-weight:700; cursor:pointer; font-size:0.88rem; box-shadow:0 4px 10px rgba(124,58,237,0.25);"><i class="fas fa-plus"></i> Add Credit</button>
            <button type="button" onclick="deleteSelectedListRows()" style="width:40px; height:40px; border-radius:50%; background:#ef4444; color:#fff; border:none; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:1.1rem; box-shadow:0 4px 10px rgba(239,68,68,0.2); transition:0.2s;" onmouseover="this.style.background='#dc2626'" onmouseout="this.style.background='#ef4444'">🗑️</button>
        </div>
        <div id="creditTable">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" class="select-all-checkbox" onclick="toggleSelectAll(this, 'creditTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Date</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Customer Name</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Invoice Number</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Amount</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for bank in banks if (bank.transaction_type or '')|lower == 'credit' %}
                        <tr style="border-top:1px solid #f1f5f9;">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox" value="{{ bank.id if bank.id is defined else bank.invoice_number }}"></td>
                            <td style="padding:14px 16px;color:#374151;">{{ bank.date or '' }}</td>
                            <td style="padding:14px 16px;color:#374151;">{{ bank.customer_name or '-' }}</td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">{{ bank.invoice_number or '-' }}</span></td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ bank.amount or 0 }}">{{ '%.2f'|format(bank.amount or 0) }}</span></td>
                        </tr>
                        {% else %}
                        <tr><td colspan="5" class="muted" style="padding:20px;text-align:center;">No credit transactions saved yet.</td></tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
            <p class="muted" style="margin-top:14px;" id="creditRecordCount">Total Records : {{ banks|selectattr('transaction_type', 'equalto', 'credit')|list|length }}</p>
        </div>
        <div id="debitTable" style="display:none;">
            <div class="table-responsive" style="background:#fff;border-radius:12px;overflow:hidden;">
                <table style="width:100%;border-collapse:collapse;">
                    <thead>
                        <tr style="background:linear-gradient(135deg,#f3e8ff,#fde8f0);">
                            <th style="width:44px;padding:14px 16px;text-align:left;"><input type="checkbox" class="select-all-checkbox" onclick="toggleSelectAll(this, 'debitTable')"></th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Date</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Vendor Name</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Invoice Number</th>
                            <th style="padding:14px 16px;text-align:left;color:#7c3aed;font-weight:700;">Amount</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for bank in banks if (bank.transaction_type or '')|lower == 'debit' %}
                        <tr style="border-top:1px solid #f1f5f9;">
                            <td style="padding:14px 16px;"><input type="checkbox" class="row-checkbox" value="{{ bank.id if bank.id is defined else bank.invoice_number }}"></td>
                            <td style="padding:14px 16px;color:#374151;">{{ bank.date or '' }}</td>
                            <td style="padding:14px 16px;color:#374151;">{{ bank.customer_name or '-' }}</td>
                            <td style="padding:14px 16px;"><span style="color:#7c3aed;font-weight:700;">{{ bank.invoice_number or '-' }}</span></td>
                            <td style="padding:14px 16px;color:#374151;"><span class="currency-label">SGD</span> <span class="converted-amount" data-base-val="{{ bank.amount or 0 }}">{{ '%.2f'|format(bank.amount or 0) }}</span></td>
                        </tr>
                        {% else %}
                        <tr><td colspan="5" class="muted" style="padding:20px;text-align:center;">No debit transactions saved yet.</td></tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
            <p class="muted" style="margin-top:14px;" id="debitRecordCount">Total Records : {{ banks|selectattr('transaction_type', 'equalto', 'debit')|list|length }}</p>
        </div>
    </div>
</div>
<script>
function filterBankRows(event, mode) {
    if (event) event.preventDefault();
    var creditTable = document.getElementById('creditTable'); var debitTable = document.getElementById('debitTable');
    var creditBtn = document.getElementById('creditBtn'); var debitBtn = document.getElementById('debitBtn'); var addBankBtn = document.getElementById('addBankBtn');
    creditBtn.style.background = mode === 'credit' ? 'linear-gradient(135deg,#7c3aed,#a855f7)' : '#fff';
    creditBtn.style.color = mode === 'credit' ? '#fff' : '#1e293b';
    debitBtn.style.background = mode === 'debit' ? 'linear-gradient(135deg,#7c3aed,#a855f7)' : '#fff';
    debitBtn.style.color = mode === 'debit' ? '#fff' : '#1e293b';
    creditTable.style.display = mode === 'credit' ? '' : 'none'; debitTable.style.display = mode === 'debit' ? '' : 'none';
    addBankBtn.innerHTML = mode === 'credit' ? '<i class="fas fa-plus"></i> Add Credit' : '<i class="fas fa-plus"></i> Add Vendor';
    addBankBtn.setAttribute('onclick', "window.location.href='{{ url_for('bank_master_new') }}?type=" + mode + "'");
}
function toggleSelectAll(sourceCheckbox, containerId) {
    var container = document.getElementById(containerId);
    container.querySelectorAll('.row-checkbox').forEach(cb => cb.checked = sourceCheckbox.checked);
}
function deleteSelectedListRows() {
    var creditTable = document.getElementById('creditTable');
    var activeContainer = (creditTable.style.display !== 'none') ? creditTable : document.getElementById('debitTable');
    var selectedCheckboxes = activeContainer.querySelectorAll('.row-checkbox:checked');
    if (selectedCheckboxes.length === 0) { alert('Please select at least one row to delete.'); return; }
    if (!confirm('Delete selected row(s)?')) return;
    selectedCheckboxes.forEach(cb => { var row = cb.closest('tr'); if (row) row.remove(); });
}
function filterBank() {}
</script>
{% endblock %}""")
print("✔ templates/bank_master.html fully restored loop records.")

print("\n🎉 Master restoration deployment script compiled! Run your execution commands to synchronize codebase.")
