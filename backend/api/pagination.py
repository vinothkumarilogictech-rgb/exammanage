def paginate(items, page=1, page_size=50):
    page = max(1, int(page or 1)); page_size = min(200, max(1, int(page_size or 50)))
    start = (page - 1) * page_size
    return {'results': items[start:start + page_size], 'page': page, 'page_size': page_size, 'count': len(items)}
