#!/usr/bin/env python3
"""
rog-fan-keyd — ROG Fan-Hotkey Daemon mit OSD
Lauscht auf KEY_PROG4 (Fan-Taste) und rotiert das Profil via asusctl,
zeigt 2s-OSD beim Wechsel an.
Track 2 v0.6
"""
import os
import sys
import math
import subprocess
import signal
import time
import threading

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError:
    print("Fehlende Abhängigkeit / Missing dependency:", file=sys.stderr)
    print("  sudo apt install python3-evdev", file=sys.stderr)
    sys.exit(1)

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Gdk  # noqa: E402

# === Const ===
VERSION = '0.6'
LANG = os.environ.get('ROG_LANG', 'de').lower()
TARGET_KEY = ecodes.KEY_PROG4   # code 203
DEBOUNCE_S = 0.4
OSD_DURATION_MS = 2000
OSD_WIDTH = 360
OSD_HEIGHT = 110

REAL_HOME = os.path.expanduser('~')
CONFIG_DIR = os.path.join(REAL_HOME, '.config', 'rog-fan')
LAST_FILE = os.path.join(CONFIG_DIR, 'last_profile')

# Profile → (hex accent, emoji glyph, normalized rgb)
def _hex_to_rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16) / 255.0,
            int(h[2:4], 16) / 255.0,
            int(h[4:6], 16) / 255.0)

PROFILE_META = {
    'Quiet':       {'hex': '#3b82f6', 'icon': '🌙'},
    'Balanced':    {'hex': '#22c55e', 'icon': '⚖'},
    'Performance': {'hex': '#f97316', 'icon': '🚀'},
}
for _p, _m in PROFILE_META.items():
    _m['rgb'] = _hex_to_rgb(_m['hex'])

# === i18n ===
T_DE = {
    'osd_hint': 'Fan-Taste · Profil gewechselt',
    'osd_quiet': 'Leise',
    'osd_balanced': 'Ausgewogen',
    'osd_performance': 'Leistung',
    'err_no_devices': 'Keine Input-Devices mit KEY_PROG4 gefunden',
    'err_asusctl': 'asusctl nicht gefunden — bitte install-rog-fan.sh ausführen',
    'log_listening_on': 'Lausche auf',
    'log_starting': 'rog-fan-keyd gestartet',
    'log_stopping': 'rog-fan-keyd wird beendet',
}
T_EN = {
    'osd_hint': 'Fan key · Profile changed',
    'osd_quiet': 'Quiet',
    'osd_balanced': 'Balanced',
    'osd_performance': 'Performance',
    'err_no_devices': 'No input devices with KEY_PROG4 found',
    'err_asusctl': 'asusctl not found — please run install-rog-fan.sh',
    'log_listening_on': 'Listening on',
    'log_starting': 'rog-fan-keyd started',
    'log_stopping': 'rog-fan-keyd stopping',
}
T = T_DE if LANG == 'de' else T_EN


# === Helpers ===
def log(msg):
    print(f"[rog-fan-keyd] {msg}", flush=True)


def run_asusctl(*args, timeout=3):
    try:
        r = subprocess.run(['asusctl', *args],
                           capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout or r.stderr).strip()
    except Exception as e:
        return False, str(e)


def get_current_profile():
    ok, out = run_asusctl('profile', 'get')
    if not ok:
        return None
    for line in out.splitlines():
        for p in ('Quiet', 'Balanced', 'Performance'):
            if p in line:
                return p
    return out.strip().capitalize() if out.strip() else None


def write_last_profile(profile_cap):
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(LAST_FILE, 'w') as f:
            f.write(profile_cap.lower())
    except Exception as e:
        log(f"write_last_profile failed: {e}")


def _rounded_rect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r,     r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0,            math.pi / 2)
    cr.arc(x + r,     y + h - r, r, math.pi / 2,  math.pi)
    cr.arc(x + r,     y + r,     r, math.pi,      3 * math.pi / 2)
    cr.close_path()


def _profile_label(profile_cap):
    key = 'osd_' + profile_cap.lower()
    return T.get(key, profile_cap)


# === OSD ===
class OSDWindow(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.set_accept_focus(False)
        self.set_can_focus(False)
        self.set_resizable(False)
        self.set_default_size(OSD_WIDTH, OSD_HEIGHT)
        self._accent_rgb = (0.97, 0.45, 0.09)
        self._setup_transparency()
        self.connect('draw', self._on_draw)
        self._build_ui()
        self._hide_timer = None
        self._current_profile = None

    def _setup_transparency(self):
        screen = self.get_screen()
        visual = screen.get_rgba_visual() if screen else None
        if visual is not None:
            self.set_visual(visual)
        self.set_app_paintable(True)

    def _on_draw(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        # transparent base
        cr.save()
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(0)  # CLEAR
        cr.paint()
        cr.restore()
        # rounded dark background
        radius = 14
        cr.set_source_rgba(0.08, 0.08, 0.10, 0.92)
        _rounded_rect(cr, 0, 0, w, h, radius)
        cr.fill()
        # accent bar (links)
        r, g, b = self._accent_rgb
        cr.set_source_rgba(r, g, b, 0.95)
        _rounded_rect(cr, 0, 0, 6, h, 3)
        cr.fill()
        return False

    def _build_ui(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        outer.set_margin_start(22)
        outer.set_margin_end(18)
        outer.set_margin_top(14)
        outer.set_margin_bottom(14)

        self._icon_label = Gtk.Label()
        self._icon_label.set_markup(
            '<span font="28" foreground="#ffffff">🚀</span>')
        self._icon_label.set_valign(Gtk.Align.CENTER)
        outer.pack_start(self._icon_label, False, False, 0)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        vbox.set_valign(Gtk.Align.CENTER)

        self._title_label = Gtk.Label(xalign=0)
        self._title_label.set_markup(
            '<span font="18" weight="bold" foreground="#ffffff">—</span>')

        self._hint_label = Gtk.Label(xalign=0)
        self._hint_label.set_markup(
            f'<span font="10" foreground="#b8b8c0">{T["osd_hint"]}</span>')

        vbox.pack_start(self._title_label, False, False, 0)
        vbox.pack_start(self._hint_label, False, False, 0)
        outer.pack_start(vbox, True, True, 0)

        self.add(outer)

    def show_profile(self, profile_cap):
        meta = PROFILE_META.get(profile_cap, {
            'rgb': (0.97, 0.45, 0.09),
            'icon': '•',
        })
        self._accent_rgb = meta['rgb']
        accent_hex = PROFILE_META.get(profile_cap, {}).get('hex', '#f97316')
        self._current_profile = profile_cap

        self._icon_label.set_markup(
            f'<span font="28" foreground="{accent_hex}">{meta["icon"]}</span>'
        )
        title = GLib.markup_escape_text(_profile_label(profile_cap))
        self._title_label.set_markup(
            f'<span font="18" weight="bold" foreground="#ffffff">{title}</span>'
        )
        self._hint_label.set_markup(
            f'<span font="10" foreground="#b8b8c0">{T["osd_hint"]}</span>'
        )

        if self._hide_timer is not None:
            GLib.source_remove(self._hide_timer)
            self._hide_timer = None

        self.queue_draw()
        self.show_all()
        self._position_top_center()
        self._hide_timer = GLib.timeout_add(OSD_DURATION_MS, self._on_timeout)

    def _position_top_center(self):
        display = Gdk.Display.get_default()
        if display is None:
            return
        monitor = display.get_primary_monitor() or display.get_monitor(0)
        if monitor is None:
            return
        geo = monitor.get_geometry()
        w, h = self.get_size()
        x = geo.x + (geo.width - w) // 2
        y = geo.y + int(geo.height * 0.12)
        self.move(x, y)

    def _on_timeout(self):
        self.hide()
        self._hide_timer = None
        return False


# === Key Listener ===
class FanKeyDaemon:
    def __init__(self):
        self.osd = OSDWindow()
        self.devices = []
        self.last_trigger = 0.0
        self._scan_devices()

    def _scan_devices(self):
        self.devices = []
        for path in list_devices():
            try:
                dev = InputDevice(path)
                caps = dev.capabilities().get(ecodes.EV_KEY, [])
                if TARGET_KEY in caps:
                    self.devices.append(dev)
                    log(f"{T['log_listening_on']}: {dev.path} ({dev.name})")
                else:
                    dev.close()
            except Exception:
                continue

    def start(self):
        if not self.devices:
            log(T['err_no_devices'])
            return
        for dev in self.devices:
            t = threading.Thread(target=self._read_loop,
                                 args=(dev,), daemon=True)
            t.start()

    def _read_loop(self, dev):
        try:
            for event in dev.read_loop():
                if (event.type == ecodes.EV_KEY
                        and event.code == TARGET_KEY
                        and event.value == 1):
                    GLib.idle_add(self._on_keypress)
        except OSError as e:
            log(f"Device {dev.path} disconnected: {e}")
        except Exception as e:
            log(f"read_loop error on {dev.path}: {e}")

    def _on_keypress(self):
        now = time.monotonic()
        if now - self.last_trigger < DEBOUNCE_S:
            return False
        self.last_trigger = now
        ok, _ = run_asusctl('profile', 'next')
        if not ok:
            log("profile next failed")
            return False
        time.sleep(0.15)
        prof = get_current_profile()
        if prof:
            write_last_profile(prof)
            self.osd.show_profile(prof)
        return False


def _check_asusctl():
    try:
        subprocess.run(['asusctl', '--help'],
                       capture_output=True, timeout=2)
        return True
    except Exception:
        return False


def main():
    if not _check_asusctl():
        log(T['err_asusctl'])
        sys.exit(2)
    log(T['log_starting'])
    daemon = FanKeyDaemon()
    daemon.start()

    def _on_signal(signum, frame):
        log(T['log_stopping'])
        GLib.idle_add(Gtk.main_quit)

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)

    try:
        Gtk.main()
    finally:
        log(T['log_stopping'])


if __name__ == '__main__':
    main()
