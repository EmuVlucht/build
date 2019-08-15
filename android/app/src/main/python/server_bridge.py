"""
server_bridge.py — Chaquopy bridge untuk uploadserver v6.
"""

import os
import threading
import http.server
import inspect
import base64
import functools

_server      = None
_pause_event = threading.Event()
_pause_event.set()
_lock        = threading.Lock()


def _find_handler_class():
    """Cari handler class dari uploadserver."""
    import uploadserver
    for candidate in ("UploadHTTPRequestHandler", "SimpleHTTPRequestHandler",
                      "Handler", "HTTPRequestHandler"):
        cls = getattr(uploadserver, candidate, None)
        if cls and isinstance(cls, type):
            if issubclass(cls, http.server.BaseHTTPRequestHandler):
                return cls
    for _, obj in inspect.getmembers(uploadserver, inspect.isclass):
        if (obj is not http.server.BaseHTTPRequestHandler and
                issubclass(obj, http.server.BaseHTTPRequestHandler)):
            return obj
    try:
        import importlib
        m = importlib.import_module("uploadserver.__main__")
        for _, obj in inspect.getmembers(m, inspect.isclass):
            if (obj is not http.server.BaseHTTPRequestHandler and
                    issubclass(obj, http.server.BaseHTTPRequestHandler)):
                return obj
    except Exception:
        pass
    return None


def _make_auth_checker(user_pass_str):
    if not user_pass_str or ':' not in user_pass_str:
        return None
    expected = base64.b64encode(user_pass_str.encode()).decode()
    def check(auth_header):
        if not auth_header:
            return False
        parts = auth_header.split(' ', 1)
        if len(parts) != 2 or parts[0].lower() != 'basic':
            return False
        return parts[1] == expected
    return check


def start(directory, port=8000, theme="auto",
          basic_auth="", basic_auth_upload=""):

    global _server, _pause_event

    with _lock:
        if _server is not None:
            return "already_running"

        _pause_event.set()

        BaseHandler = _find_handler_class()
        if BaseHandler is None:
            return "error: cannot find uploadserver handler class"

        # Set theme
        try:
            import uploadserver as _usmod
            if hasattr(_usmod, 'theme'):
                _usmod.theme = str(theme)
            if hasattr(BaseHandler, 'theme'):
                BaseHandler.theme = str(theme)
        except Exception:
            pass

        # os.chdir sebagai fallback
        try:
            os.chdir(str(directory))
        except Exception:
            pass

        ev            = _pause_event
        auth_check    = _make_auth_checker(basic_auth)
        auth_up_check = _make_auth_checker(basic_auth_upload)
        dir_str       = str(directory)

        # Coba buat handler dengan directory kwarg (cara paling kompatibel)
        try:
            # Test apakah BaseHandler menerima directory kwarg
            import inspect as _inspect
            sig = _inspect.signature(BaseHandler.__init__)
            has_dir_kwarg = 'directory' in sig.parameters
        except Exception:
            has_dir_kwarg = False

        class PausableHandler(BaseHandler):
            def __init__(self, *args, **kwargs):
                if has_dir_kwarg:
                    kwargs.setdefault('directory', dir_str)
                super().__init__(*args, **kwargs)

            def handle(self):
                ev.wait()
                super().handle()

            def do_HEAD(self):
                if auth_check and not auth_check(self.headers.get('Authorization')):
                    self._send_auth_required("Access"); return
                super().do_HEAD()

            def do_GET(self):
                if auth_check and not auth_check(self.headers.get('Authorization')):
                    self._send_auth_required("Access"); return
                super().do_GET()

            def do_POST(self):
                checker = auth_check or auth_up_check
                if checker and not checker(self.headers.get('Authorization')):
                    self._send_auth_required("Upload"); return
                super().do_POST()

            def do_PUT(self):
                checker = auth_check or auth_up_check
                if checker and not checker(self.headers.get('Authorization')):
                    self._send_auth_required("Upload"); return
                super().do_PUT()

            def _send_auth_required(self, realm="Access"):
                self.send_response(401)
                self.send_header('WWW-Authenticate', f'Basic realm="{realm}"')
                self.send_header('Content-Type', 'text/plain')
                self.send_header('Content-Length', '0')
                self.end_headers()

        try:
            _server = http.server.HTTPServer(("0.0.0.0", int(port)), PausableHandler)
            _server.allow_reuse_address = True
            t = threading.Thread(target=_server.serve_forever, daemon=True)
            t.start()
            return "ok"
        except OSError as e:
            _server = None
            return f"error: {e}"
        except Exception as e:
            _server = None
            return f"error: {e}"


def pause():
    _pause_event.clear()
    return "paused"

def resume():
    _pause_event.set()
    return "resumed"

def stop():
    global _server
    with _lock:
        if _server is not None:
            _pause_event.set()
            try:
                _server.shutdown()
                _server.server_close()
            except Exception:
                pass
            _server = None
    return "stopped"

def get_status():
    if _server is None:
        return "idle"
    if not _pause_event.is_set():
        return "paused"
    return "active"
