def api_exception_handler(error):
    return {'success': False, 'message': str(error)}, 500
