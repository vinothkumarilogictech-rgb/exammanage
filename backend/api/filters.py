# API filter helpers. Query-string filtering is kept close to each Flask view
# so the web UI and mobile API share the same model/query rules.

def text(value):
    return (value or '').strip()
