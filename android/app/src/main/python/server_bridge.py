"""
server_bridge.py — Chaquopy bridge untuk uploadserver v6.
Fix: gunakan os.chdir() saja sebagai satu-satunya cara set directory.
MRO inspection dihapus — gunakan os.chdir() saja.
"""

import os
import threading
import http.server
import inspect
import base64

_server      = None
_pause_event = threading.Event()
_pause_event.set()
_lock        = threading.Lock()


def _find_handler_class():
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

        # Pindah ke direktori yang dipilih.
        # os.chdir() adalah cara paling reliable — uploadserver serve dari CWD.
        # Tidak pakai directory kwarg karena MRO inspection tidak reliable.
        try:
            os.chdir(str(directory))
        except Exception as e:
            return f"error: cannot chdir to {directory}: {e}"

        ev            = _pause_event
        auth_check    = _make_auth_checker(basic_auth)
        auth_up_check = _make_auth_checker(basic_auth_upload)

        class PausableHandler(BaseHandler):
            # Tidak override __init__ — CWD sudah benar via os.chdir()

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
            # allow_reuse_address HARUS diset sebelum bind — pakai subclass
            class ReusableHTTPServer(http.server.HTTPServer):
                allow_reuse_address = True

            _server = ReusableHTTPServer(("0.0.0.0", int(port)), PausableHandler)
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
