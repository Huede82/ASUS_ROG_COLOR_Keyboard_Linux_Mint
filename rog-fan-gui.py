#!/usr/bin/env python3
"""
rog-fan-gui — GTK3 GUI für ROG Lüftersteuerung
ASUS ROG Fan Control (asusctl v6 Frontend)
Track 2 v0.5 "Standard"
"""
import os
import sys
import glob
import shutil
import subprocess

try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, GLib, Gdk
except (ImportError, ValueError):
    print("Fehlende Abhängigkeiten / Missing dependencies!")
    print("sudo apt install python3-gi gir1.2-gtk-3.0")
    sys.exit(1)

# ── Tray (optional) ──────────────────────────────────────────
INDICATOR_LIB = None
AppIndicator3 = None
try:
    gi.require_version('AyatanaAppIndicator3', '0.1')
    from gi.repository import AyatanaAppIndicator3 as AppIndicator3  # type: ignore
    INDICATOR_LIB = 'ayatana'
except (ValueError, ImportError):
    try:
        gi.require_version('AppIndicator3', '0.1')
        from gi.repository import AppIndicator3  # type: ignore
        INDICATOR_LIB = 'classic'
    except (ValueError, ImportError):
        AppIndicator3 = None

# ── Constants ────────────────────────────────────────────────
VERSION = '0.5'
LANG = os.environ.get('ROG_LANG', 'de').lower()
if LANG not in ('de', 'en'):
    LANG = 'de'

_sudo_user = os.environ.get('SUDO_USER')
if _sudo_user:
    REAL_HOME = os.path.expanduser('~' + _sudo_user)
else:
    REAL_HOME = os.path.expanduser('~')
if not REAL_HOME or REAL_HOME.startswith('~'):
    REAL_HOME = os.environ.get('HOME', '/tmp')

CONFIG_DIR = os.path.join(REAL_HOME, '.config', 'rog-fan')
LAST_FILE = os.path.join(CONFIG_DIR, 'last_profile')
PROFILES = ['Quiet', 'Balanced', 'Performance']
POLL_INTERVAL_S = 2

# ── i18n ─────────────────────────────────────────────────────
T = {
    'de': {
        'title': 'ROG Fan Control',
        'subtitle': 'ASUS ROG Lüftersteuerung',
        'profile_quiet': 'Leise',
        'profile_balanced': 'Ausgewogen',
        'profile_performance': 'Leistung',
        'btn_restore': '↻  Wiederherstellen',
        'btn_next': '→  Nächstes',
        'btn_about': 'Über',
        'lbl_current_profile': 'Aktuelles Profil',
        'lbl_platform_kernel': 'Plattform (Kernel)',
        'lbl_throttle': 'throttle_policy',
        'lbl_power': 'Stromquelle',
        'lbl_cpu_temp': 'CPU-Temperatur',
        'lbl_fans': 'Lüfter',
        'lbl_last_saved': 'Zuletzt gespeichert',
        'power_ac': 'Netz (AC)',
        'power_bat': 'Akku',
        'unknown': 'unbekannt',
        'na': '—',
        'err_asusctl_missing': 'asusctl wurde nicht gefunden.\n\nBitte zuerst das Installations-Skript ausführen:\nsudo bash install-rog-fan.sh',
        'err_asusctl_missing_title': 'asusctl fehlt',
        'err_set_failed': 'Profil konnte nicht gesetzt werden:\n\n{msg}',
        'err_set_failed_title': 'Fehler',
        'err_asusd_down': 'asusd-Dienst läuft nicht. Starten mit:\nsudo systemctl start asusd',
        'tray_show': 'Fenster anzeigen / verstecken',
        'tray_quit': 'Beenden',
        'about_title': 'ROG Fan Control',
        'about_comment': 'Grafische Lüftersteuerung für ASUS ROG Notebooks\nasusctl v6 Frontend',
        'about_diagnose_hint': 'Bei Problemen: bash rog-fan-diagnose.sh',
        'about_model': 'Hardware',
    },
    'en': {
        'title': 'ROG Fan Control',
        'subtitle': 'ASUS ROG Fan Control',
        'profile_quiet': 'Quiet',
        'profile_balanced': 'Balanced',
        'profile_performance': 'Performance',
        'btn_restore': '↻  Restore',
        'btn_next': '→  Next',
        'btn_about': 'About',
        'lbl_current_profile': 'Current profile',
        'lbl_platform_kernel': 'Platform (kernel)',
        'lbl_throttle': 'throttle_policy',
        'lbl_power': 'Power source',
        'lbl_cpu_temp': 'CPU temperature',
        'lbl_fans': 'Fans',
        'lbl_last_saved': 'Last saved',
        'power_ac': 'AC (mains)',
        'power_bat': 'Battery',
        'unknown': 'unknown',
        'na': '—',
        'err_asusctl_missing': 'asusctl was not found.\n\nPlease run the install script first:\nsudo bash install-rog-fan.sh',
        'err_asusctl_missing_title': 'asusctl missing',
        'err_set_failed': 'Could not set profile:\n\n{msg}',
        'err_set_failed_title': 'Error',
        'err_asusd_down': 'asusd service not running. Start with:\nsudo systemctl start asusd',
        'tray_show': 'Show / hide window',
        'tray_quit': 'Quit',
        'about_title': 'ROG Fan Control',
        'about_comment': 'Graphical fan control for ASUS ROG notebooks\nasusctl v6 frontend',
        'about_diagnose_hint': 'If problems occur: bash rog-fan-diagnose.sh',
        'about_model': 'Hardware',
    },
}


def t(key, **kw):
    s = T.get(LANG, T['en']).get(key) or T['en'].get(key, key)
    return s.format(**kw) if kw else s


# ── CSS ──────────────────────────────────────────────────────
CSS = b"""
.profile-btn {
    padding: 18px 24px;
    border-radius: 10px;
    font-size: 14pt;
    background-color: #2d2d33;
    background-image: none;
    color: #d0d0d0;
    border: 1px solid #3c3c44;
}
.profile-btn:hover {
    background-color: #3a3a42;
    background-image: none;
}
.profile-active {
    background-image: linear-gradient(135deg, #ff5500, #ff8800);
    background-color: #ff5500;
    color: #ffffff;
    font-weight: bold;
    border: 1px solid #ff8800;
}
.profile-active:hover {
    background-image: linear-gradient(135deg, #ff6611, #ff9911);
}
.status-key { color: #888; }
.status-value { font-family: monospace; }
.temp-cool { color: #2ecc71; font-family: monospace; font-weight: bold; }
.temp-warm { color: #f39c12; font-family: monospace; font-weight: bold; }
.temp-hot  { color: #e74c3c; font-family: monospace; font-weight: bold; }
.section-sep { margin-top: 6px; margin-bottom: 6px; }
"""


# ── Sensor / asusctl helpers ─────────────────────────────────
def _read_file(path):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except OSError:
        return None


def run_asusctl(*args, timeout=3):
    """Run asusctl with given args. Returns (ok, stdout_or_stderr)."""
    if not shutil.which('asusctl'):
        return False, 'asusctl not found'
    try:
        r = subprocess.run(
            ['asusctl', *args],
            capture_output=True, text=True, timeout=timeout,
        )
        if r.returncode == 0:
            return True, (r.stdout or '').strip()
        return False, (r.stderr or r.stdout or '').strip()
    except subprocess.TimeoutExpired:
        return False, 'timeout'
    except Exception as e:
        return False, str(e)


def get_current_profile():
    """Return one of 'Quiet'/'Balanced'/'Performance' or None."""
    ok, out = run_asusctl('profile', 'get')
    if not ok or not out:
        return None
    # asusctl v6 prints something like "Active profile is Balanced"
    # or just "Balanced" depending on build. Be defensive.
    low = out.lower()
    for p in PROFILES:
        if p.lower() in low:
            return p
    return None


def read_platform_profile():
    v = _read_file('/sys/firmware/acpi/platform_profile')
    return v if v else None


def read_throttle_policy():
    """Returns (int, label) or (None, '')."""
    v = _read_file('/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy')
    if v is None:
        return None, ''
    try:
        n = int(v)
    except ValueError:
        return None, ''
    label = {0: 'Balanced', 1: 'Performance', 2: 'Quiet'}.get(n, '?')
    return n, label


def read_power_source():
    """Returns (on_ac: bool, battery_pct: int|None)."""
    on_ac = False
    for p in glob.glob('/sys/class/power_supply/*/online'):
        # Only AC-type supplies (AC*, ADP*, ACAD*)
        name = os.path.basename(os.path.dirname(p)).upper()
        if not (name.startswith('AC') or name.startswith('ADP') or name.startswith('ACAD')):
            continue
        v = _read_file(p)
        if v == '1':
            on_ac = True
            break
    bat_pct = None
    for p in glob.glob('/sys/class/power_supply/BAT*/capacity'):
        v = _read_file(p)
        if v is not None:
            try:
                bat_pct = int(v)
                break
            except ValueError:
                pass
    return on_ac, bat_pct


def read_cpu_temp_max():
    """Returns float °C or None. Scans k10temp/coretemp/asus-* hwmon devices."""
    best = None
    for hw in glob.glob('/sys/class/hwmon/hwmon*'):
        name = _read_file(os.path.join(hw, 'name')) or ''
        if name not in ('k10temp', 'coretemp', 'zenpower', 'asus-isa', 'asus_custom_fan_curve'):
            # Also accept asus-* names broadly
            if not name.startswith('asus'):
                continue
        for tf in glob.glob(os.path.join(hw, 'temp*_input')):
            v = _read_file(tf)
            if v is None:
                continue
            try:
                c = int(v) / 1000.0
            except ValueError:
                continue
            if c < 0 or c > 150:
                continue
            if best is None or c > best:
                best = c
    return best


def read_fans():
    """Returns list of (label, rpm)."""
    result = []
    for hw in glob.glob('/sys/class/hwmon/hwmon*'):
        for fan_in in sorted(glob.glob(os.path.join(hw, 'fan*_input'))):
            v = _read_file(fan_in)
            if v is None:
                continue
            try:
                rpm = int(v)
            except ValueError:
                continue
            base = os.path.basename(fan_in)  # fan1_input
            idx = base.replace('fan', '').replace('_input', '')
            label_file = os.path.join(hw, f'fan{idx}_label')
            label = _read_file(label_file)
            if not label:
                # Heuristic: idx 1 → cpu_fan, 2 → gpu_fan, else fan_idx
                label = {'1': 'cpu_fan', '2': 'gpu_fan'}.get(idx, f'fan{idx}')
            result.append((label, rpm))
    return result


def get_dmi_model():
    for p in ('/sys/class/dmi/id/product_name',
              '/sys/devices/virtual/dmi/id/product_name'):
        v = _read_file(p)
        if v:
            return v
    return t('unknown')


def is_asusd_running():
    try:
        r = subprocess.run(
            ['systemctl', 'is-active', '--quiet', 'asusd'],
            timeout=2,
        )
        return r.returncode == 0
    except Exception:
        return True  # assume yes; don't block UI


# ── Main Window ──────────────────────────────────────────────
class FanGui(Gtk.Window):
    def __init__(self):
        super().__init__(title=t('title'))
        self.set_default_size(540, 560)
        self.set_resizable(False)
        self.set_icon_name('fan-symbolic')

        self.profile_buttons = {}
        self.tray = None

        self._load_css()
        self._build_headerbar()
        self._build_body()
        self.refresh()
        GLib.timeout_add_seconds(POLL_INTERVAL_S, self._poll)

    # ── Setup ────────────────────────────────────────────────
    def _load_css(self):
        provider = Gtk.CssProvider()
        try:
            provider.load_from_data(CSS)
        except Exception as e:
            print(f"CSS load failed: {e}", file=sys.stderr)
            return
        screen = Gdk.Screen.get_default()
        if screen is not None:
            Gtk.StyleContext.add_provider_for_screen(
                screen, provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
            )

    def _build_headerbar(self):
        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        hb.set_title(t('title'))
        hb.set_subtitle(t('subtitle'))

        about_btn = Gtk.Button()
        about_btn.set_tooltip_text(t('btn_about'))
        about_btn.set_relief(Gtk.ReliefStyle.NONE)
        icon = Gtk.Image.new_from_icon_name('help-about-symbolic', Gtk.IconSize.BUTTON)
        about_btn.set_image(icon)
        about_btn.connect('clicked', self.on_about_clicked)
        hb.pack_end(about_btn)

        self.set_titlebar(hb)

    def _build_body(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        outer.set_margin_top(16)
        outer.set_margin_bottom(16)
        outer.set_margin_start(18)
        outer.set_margin_end(18)

        outer.pack_start(self._build_profile_row(), False, False, 0)
        outer.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 6)
        outer.pack_start(self._build_status_grid(), False, False, 0)
        outer.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 6)
        outer.pack_start(self._build_action_row(), False, False, 0)

        self.add(outer)

    def _build_profile_row(self):
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        hbox.set_homogeneous(True)

        labels = {
            'Quiet': t('profile_quiet'),
            'Balanced': t('profile_balanced'),
            'Performance': t('profile_performance'),
        }
        icons = {'Quiet': '🌙', 'Balanced': '⚖', 'Performance': '🚀'}

        for prof in PROFILES:
            btn = Gtk.Button()
            lbl = Gtk.Label()
            lbl.set_markup(
                f'<span size="large" weight="bold">{icons[prof]}</span>\n'
                f'<span size="medium">{GLib.markup_escape_text(labels[prof])}</span>'
            )
            lbl.set_justify(Gtk.Justification.CENTER)
            btn.add(lbl)
            btn.get_style_context().add_class('profile-btn')
            btn.connect('clicked', self.on_profile_clicked, prof)
            self.profile_buttons[prof] = btn
            hbox.pack_start(btn, True, True, 0)

        return hbox

    def _build_status_grid(self):
        grid = Gtk.Grid()
        grid.set_row_spacing(6)
        grid.set_column_spacing(18)

        rows = [
            ('lbl_current_profile', 'val_current'),
            ('lbl_platform_kernel', 'val_platform'),
            ('lbl_throttle',        'val_throttle'),
            ('lbl_power',           'val_power'),
            ('lbl_cpu_temp',        'val_temp'),
            ('lbl_fans',            'val_fans'),
        ]
        self.value_labels = {}
        for i, (key, attr) in enumerate(rows):
            k = Gtk.Label(label=t(key) + ':')
            k.set_xalign(0)
            k.get_style_context().add_class('status-key')
            v = Gtk.Label(label=t('na'))
            v.set_xalign(0)
            v.set_use_markup(True)
            v.get_style_context().add_class('status-value')
            grid.attach(k, 0, i, 1, 1)
            grid.attach(v, 1, i, 1, 1)
            self.value_labels[attr] = v

        return grid

    def _build_action_row(self):
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        self.btn_restore = Gtk.Button(label=t('btn_restore'))
        self.btn_restore.connect('clicked', self.on_restore_clicked)
        hbox.pack_start(self.btn_restore, False, False, 0)

        self.btn_next = Gtk.Button(label=t('btn_next'))
        self.btn_next.connect('clicked', self.on_next_clicked)
        hbox.pack_start(self.btn_next, False, False, 0)

        # Spacer
        hbox.pack_start(Gtk.Box(), True, True, 0)

        self.lbl_last = Gtk.Label()
        self.lbl_last.set_use_markup(True)
        self.lbl_last.set_xalign(1)
        hbox.pack_end(self.lbl_last, False, False, 0)

        return hbox

    # ── Polling / refresh ────────────────────────────────────
    def _poll(self):
        try:
            self.refresh()
        except Exception as e:
            print(f"refresh error: {e}", file=sys.stderr)
        return True

    def refresh(self):
        cur = get_current_profile()
        plat = read_platform_profile() or t('unknown')
        thr_n, thr_label = read_throttle_policy()
        on_ac, bat_pct = read_power_source()
        cpu_t = read_cpu_temp_max()
        fans = read_fans()
        last = self.read_last_profile()

        # Profile buttons highlight
        for p, btn in self.profile_buttons.items():
            sc = btn.get_style_context()
            if cur == p:
                sc.add_class('profile-active')
            else:
                sc.remove_class('profile-active')

        # Current profile (with colored dot)
        if cur:
            color = {'Quiet': '#3498db', 'Balanced': '#2ecc71', 'Performance': '#e67e22'}.get(cur, '#aaa')
            self.value_labels['val_current'].set_markup(
                f'<span font_family="monospace">{GLib.markup_escape_text(cur)}</span>  '
                f'<span foreground="{color}" size="x-large">●</span>'
            )
        else:
            self.value_labels['val_current'].set_markup(
                f'<span font_family="monospace">{t("unknown")}</span>'
            )

        # platform_profile
        self.value_labels['val_platform'].set_markup(
            f'<span font_family="monospace">{GLib.markup_escape_text(plat)}</span>'
        )

        # throttle_thermal_policy
        if thr_n is None:
            thr_text = t('na')
        else:
            thr_text = f'{thr_n} ({thr_label})'
        self.value_labels['val_throttle'].set_markup(
            f'<span font_family="monospace">{GLib.markup_escape_text(thr_text)}</span>'
        )

        # Power source
        if on_ac:
            power_text = t('power_ac')
            if bat_pct is not None:
                power_text += f'  ({bat_pct}%)'
        else:
            power_text = t('power_bat')
            if bat_pct is not None:
                power_text += f'  {bat_pct}%'
        self.value_labels['val_power'].set_markup(
            f'<span font_family="monospace">{GLib.markup_escape_text(power_text)}</span>'
        )

        # CPU Temp
        if cpu_t is None:
            self.value_labels['val_temp'].set_markup(
                f'<span font_family="monospace">{t("na")}</span>'
            )
        else:
            if cpu_t < 60:
                color = '#2ecc71'
            elif cpu_t < 80:
                color = '#f39c12'
            else:
                color = '#e74c3c'
            self.value_labels['val_temp'].set_markup(
                f'<span font_family="monospace" foreground="{color}" weight="bold">'
                f'{cpu_t:.0f}°C</span>'
            )

        # Fans
        if not fans:
            self.value_labels['val_fans'].set_markup(
                f'<span font_family="monospace">{t("na")}</span>'
            )
        else:
            parts = [f'{lbl}: {rpm} U/min' if LANG == 'de' else f'{lbl}: {rpm} RPM'
                     for lbl, rpm in fans]
            self.value_labels['val_fans'].set_markup(
                f'<span font_family="monospace">{GLib.markup_escape_text(", ".join(parts))}</span>'
            )

        # last saved
        if last:
            self.lbl_last.set_markup(
                f'<span foreground="#888">{t("lbl_last_saved")}: </span>'
                f'<span font_family="monospace">{GLib.markup_escape_text(last)}</span>'
            )
        else:
            self.lbl_last.set_markup(
                f'<span foreground="#888">{t("lbl_last_saved")}: {t("na")}</span>'
            )

        # Tray label
        if self.tray is not None:
            self.tray.set_label(cur)

    # ── Button callbacks ─────────────────────────────────────
    def on_profile_clicked(self, btn, profile_name):
        self.set_profile(profile_name)

    def on_restore_clicked(self, btn):
        last = self.read_last_profile()
        if not last:
            return
        cap = last.capitalize()
        if cap in PROFILES:
            self.set_profile(cap)

    def on_next_clicked(self, btn):
        ok, msg = run_asusctl('profile', 'next')
        if not ok:
            self._show_error(t('err_set_failed_title'),
                             t('err_set_failed', msg=msg))
        else:
            # asusctl next does not return new name reliably → re-detect
            new = get_current_profile()
            if new:
                self.write_last_profile(new.lower())
        self.refresh()

    def on_about_clicked(self, btn):
        dlg = Gtk.AboutDialog(transient_for=self, modal=True)
        dlg.set_program_name(t('about_title'))
        dlg.set_version(VERSION)
        dlg.set_comments(
            t('about_comment') + '\n\n'
            + t('about_model') + ': ' + get_dmi_model() + '\n\n'
            + t('about_diagnose_hint')
        )
        dlg.set_license_type(Gtk.License.MIT_X11)
        dlg.run()
        dlg.destroy()

    # ── Actions ──────────────────────────────────────────────
    def set_profile(self, profile_name_capitalized):
        if profile_name_capitalized not in PROFILES:
            return
        ok, msg = run_asusctl('profile', 'set', profile_name_capitalized)
        if not ok:
            self._show_error(t('err_set_failed_title'),
                             t('err_set_failed', msg=msg))
            self.refresh()
            return
        self.write_last_profile(profile_name_capitalized.lower())
        self.refresh()

    def read_last_profile(self):
        v = _read_file(LAST_FILE)
        if v and v.lower() in ('quiet', 'balanced', 'performance'):
            return v.lower()
        return None

    def write_last_profile(self, profile_lower):
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(LAST_FILE, 'w') as f:
                f.write(profile_lower.strip().lower() + '\n')
        except OSError as e:
            print(f"write_last_profile failed: {e}", file=sys.stderr)

    def _show_error(self, title, msg):
        dlg = Gtk.MessageDialog(
            transient_for=self, modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=title,
        )
        dlg.format_secondary_text(msg)
        dlg.run()
        dlg.destroy()

    # ── Visibility toggle (for tray) ─────────────────────────
    def toggle_visible(self):
        if self.get_visible():
            self.hide()
        else:
            self.show_all()
            self.present()


# ── Tray ─────────────────────────────────────────────────────
class FanTray:
    def __init__(self, gui):
        self.gui = gui
        self.ind = None
        if AppIndicator3 is None:
            return
        try:
            self.ind = AppIndicator3.Indicator.new(
                'rog-fan',
                'fan-symbolic',
                AppIndicator3.IndicatorCategory.HARDWARE,
            )
            self.ind.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
            self.ind.set_title(t('title'))
            self._build_menu()
        except Exception as e:
            print(f"Tray init failed: {e}", file=sys.stderr)
            self.ind = None

    def _build_menu(self):
        menu = Gtk.Menu()

        labels = {
            'Quiet': t('profile_quiet'),
            'Balanced': t('profile_balanced'),
            'Performance': t('profile_performance'),
        }
        for prof in PROFILES:
            mi = Gtk.MenuItem(label=labels[prof])
            mi.connect('activate', lambda _w, p=prof: self.gui.set_profile(p))
            menu.append(mi)

        menu.append(Gtk.SeparatorMenuItem())

        mi_next = Gtk.MenuItem(label=t('btn_next'))
        mi_next.connect('activate', lambda _w: self.gui.on_next_clicked(None))
        menu.append(mi_next)

        mi_restore = Gtk.MenuItem(label=t('btn_restore'))
        mi_restore.connect('activate', lambda _w: self.gui.on_restore_clicked(None))
        menu.append(mi_restore)

        menu.append(Gtk.SeparatorMenuItem())

        mi_show = Gtk.MenuItem(label=t('tray_show'))
        mi_show.connect('activate', lambda _w: self.gui.toggle_visible())
        menu.append(mi_show)

        mi_quit = Gtk.MenuItem(label=t('tray_quit'))
        mi_quit.connect('activate', lambda _w: Gtk.main_quit())
        menu.append(mi_quit)

        menu.show_all()
        self.ind.set_menu(menu)

    def set_label(self, profile_name_capitalized):
        if self.ind is None:
            return
        if profile_name_capitalized:
            self.ind.set_label(profile_name_capitalized[:1], 'P')
        else:
            self.ind.set_label('?', 'P')


# ── Main ─────────────────────────────────────────────────────
def main():
    if not shutil.which('asusctl'):
        dlg = Gtk.MessageDialog(
            transient_for=None, modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=t('err_asusctl_missing_title'),
        )
        dlg.format_secondary_text(t('err_asusctl_missing'))
        dlg.run()
        dlg.destroy()
        sys.exit(1)

    gui = FanGui()
    gui.connect('destroy', Gtk.main_quit)
    gui.show_all()

    if AppIndicator3 is not None:
        try:
            tray = FanTray(gui)
            if tray.ind is not None:
                gui.tray = tray
        except Exception as e:
            print(f"Tray init failed: {e}", file=sys.stderr)

    if not is_asusd_running():
        # Non-blocking warning
        print(f"WARN: {t('err_asusd_down')}", file=sys.stderr)

    Gtk.main()


if __name__ == '__main__':
    main()
