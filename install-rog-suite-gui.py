#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
install-rog-suite-gui — GTK3-Wizard für die ROG Linux Suite (RGB + Fan)
ruft install-rog-suite.sh via pkexec auf, zeigt Live-Output
Track 3 v2.0 — Suite-GUI v1.0
"""
import os
import re
import shutil
import signal
import subprocess
import threading

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk, Pango  # noqa: F401  (Pango für CSS-Konsistenz)

# ── Konstanten ────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
INSTALLER   = os.path.join(SCRIPT_DIR, "install-rog-suite.sh")
VERSION     = "1.0"
LANG_DEFAULT = os.environ.get("ROG_LANG", "de").lower()
if LANG_DEFAULT not in ("de", "en"):
    LANG_DEFAULT = "de"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[mGKHF]")

# ── i18n ──────────────────────────────────────────────────────────────────────
TR = {
    "de": {
        "title":            "ROG Suite — Installer",
        "subtitle":         "ASUS ROG RGB + Fan Control",
        "intro_header":     "Diese Suite installiert:",
        "comp_rgb":         "RGB-Modul: Tastaturbeleuchtung & Profile",
        "comp_fan":         "Fan-Modul: asusctl, rog-fan, rog-fan-keyd, systemd-Services",
        "lang_label":       "Sprache:",
        "lang_de":          "Deutsch",
        "lang_en":          "English",
        "opt_rgb":          "RGB-Modul installieren",
        "opt_fan":          "Fan-Modul installieren",
        "opt_uninstall":    "Auch deinstallieren (rückgängig)",
        "btn_install":      "Installation  ▶",
        "btn_uninstall":    "Deinstallation  ▶",
        "btn_close":        "Schließen",
        "btn_done":         "Fertig",
        "btn_about":        "Über",
        "log_header":       "Log-Ausgabe",
        "status_idle":      "Bereit",
        "status_running":   "Läuft …",
        "status_done_ok":   "✓  Erfolgreich abgeschlossen",
        "status_done_err":  "✗  Fehler aufgetreten (Exit-Code {rc})",
        "err_no_installer": "Das Wrapper-Skript wurde nicht gefunden:\n{path}\n\nBitte starte diesen Installer aus dem Repo-Ordner.",
        "err_no_installer_title": "Installer-Skript fehlt",
        "err_pkexec_missing":     "pkexec ist nicht verfügbar.\n\nBitte installieren:\n  sudo apt install policykit-1",
        "err_pkexec_missing_title": "PolicyKit fehlt",
        "err_no_module_title":    "Kein Modul ausgewählt",
        "err_no_module":          "Mindestens ein Modul muss ausgewählt sein.",
        "log_starting":     "▶  Starte {action} …\n   Befehl: {cmd}\n\n",
        "log_finished_ok":  "\n✓  {action} erfolgreich abgeschlossen.\n",
        "log_finished_err": "\n✗  {action} fehlgeschlagen (Exit-Code: {rc}).\n",
        "action_install":   "Installation",
        "action_uninstall": "Deinstallation",
        "about_title":      "ROG Suite Installer",
        "about_comment":    "Grafischer Installer für die ROG Linux Suite (RGB + Fan)",
    },
    "en": {
        "title":            "ROG Suite — Installer",
        "subtitle":         "ASUS ROG RGB + Fan Control",
        "intro_header":     "This suite installs:",
        "comp_rgb":         "RGB Module: keyboard lighting & profiles",
        "comp_fan":         "Fan Module: asusctl, rog-fan, rog-fan-keyd, systemd services",
        "lang_label":       "Language:",
        "lang_de":          "Deutsch",
        "lang_en":          "English",
        "opt_rgb":          "Install RGB module",
        "opt_fan":          "Install Fan module",
        "opt_uninstall":    "Uninstall instead (rollback)",
        "btn_install":      "Install  ▶",
        "btn_uninstall":    "Uninstall  ▶",
        "btn_close":        "Close",
        "btn_done":         "Done",
        "btn_about":        "About",
        "log_header":       "Log output",
        "status_idle":      "Ready",
        "status_running":   "Running …",
        "status_done_ok":   "✓  Completed successfully",
        "status_done_err":  "✗  Failed (exit code {rc})",
        "err_no_installer": "The wrapper script was not found:\n{path}\n\nPlease run this installer from the repo folder.",
        "err_no_installer_title": "Installer script missing",
        "err_pkexec_missing":     "pkexec is not available.\n\nPlease install:\n  sudo apt install policykit-1",
        "err_pkexec_missing_title": "PolicyKit missing",
        "err_no_module_title":    "No module selected",
        "err_no_module":          "At least one module must be selected.",
        "log_starting":     "▶  Starting {action} …\n   Command: {cmd}\n\n",
        "log_finished_ok":  "\n✓  {action} completed successfully.\n",
        "log_finished_err": "\n✗  {action} failed (exit code: {rc}).\n",
        "action_install":   "installation",
        "action_uninstall": "uninstallation",
        "about_title":      "ROG Suite Installer",
        "about_comment":    "Graphical installer for the ROG Linux Suite (RGB + Fan)",
    },
}

def t(key, **kw):
    s = TR.get(LANG_DEFAULT, TR["de"]).get(key, TR["de"].get(key, key))
    return s.format(**kw) if kw else s

# ── CSS ───────────────────────────────────────────────────────────────────────
CSS = b"""
* { -gtk-outline-radius: 0; outline: none; }
window, .background { background-color: #1e1e2e; }

headerbar, .titlebar {
    background-color: #181825; background-image: none;
    border-bottom: 1px solid #313244; box-shadow: none; padding: 4px 8px;
}
headerbar .title { color: #cba6f7; font-weight: bold; font-size: 14px; }
headerbar button {
    background: transparent; background-image: none;
    border: none; border-radius: 6px; color: #6c7086; padding: 4px 8px;
}
headerbar button:hover { background: #313244; background-image: none; color: #cdd6f4; }

label { color: #cdd6f4; }

.page-title { color: #cba6f7; font-size: 20px; font-weight: bold; }
.page-sub   { color: #6c7086; font-size: 12px; }
.section    { color: #89b4fa; font-size: 11px; font-weight: bold; letter-spacing: 1px; }
.bullet     { color: #cdd6f4; font-size: 13px; }
.status-ok  { color: #a6e3a1; font-size: 12px; font-family: monospace; }
.status-err { color: #f38ba8; font-size: 12px; font-family: monospace; }
.status-run { color: #f9e2af; font-size: 12px; font-family: monospace; }
.status-idle{ color: #6c7086; font-size: 12px; font-family: monospace; }

.log-view {
    background-color: #11111b; color: #cdd6f4;
    font-family: monospace; font-size: 11px;
    border-radius: 8px; border: 1px solid #313244;
    padding: 8px;
}

checkbutton { color: #cdd6f4; }
radiobutton { color: #cdd6f4; }

.btn-primary {
    background-color: #8839ef; background-image: none;
    color: #ffffff; border: none; border-radius: 10px;
    padding: 9px 22px; font-size: 13px; font-weight: bold; min-width: 140px;
}
.btn-primary:hover    { background-color: #9947f7; background-image: none; }
.btn-primary:active   { background-color: #7028d4; background-image: none; }
.btn-primary:disabled { background-color: #313244; background-image: none; color: #45475a; }

.btn-danger {
    background-color: #d20f39; background-image: none;
    color: #ffffff; border: none; border-radius: 10px;
    padding: 9px 22px; font-size: 13px; font-weight: bold; min-width: 140px;
}
.btn-danger:hover    { background-color: #e11e48; background-image: none; }
.btn-danger:disabled { background-color: #313244; background-image: none; color: #45475a; }

.btn-success {
    background-color: #40a02b; background-image: none;
    color: #ffffff; border: none; border-radius: 10px;
    padding: 9px 22px; font-size: 13px; font-weight: bold; min-width: 140px;
}
.btn-success:hover { background-color: #4caf33; background-image: none; }

.btn-secondary {
    background-color: #24273a; background-image: none;
    color: #a6adc8; border: 1px solid #363a4f;
    border-radius: 10px; padding: 9px 18px; font-size: 13px;
}
.btn-secondary:hover    { background-color: #313244; background-image: none; color: #cdd6f4; }
.btn-secondary:disabled { color: #45475a; }
"""

def _load_css():
    provider = Gtk.CssProvider()
    try:
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )
    except Exception:
        pass


# ── Hauptfenster ──────────────────────────────────────────────────────────────
class InstallerWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title=t("title"))
        self.set_default_size(640, 580)
        self.set_resizable(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.uninstall_mode = False
        self.script_lang = LANG_DEFAULT
        self.running = False

        self._build_header()
        self._build_body()

        self.connect("delete-event", self._on_delete)

    # ── UI Construction ────────────────────────────────────────────────────
    def _build_header(self):
        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        hb.set_title(t("title"))
        about_btn = Gtk.Button.new_from_icon_name(
            "help-about-symbolic", Gtk.IconSize.BUTTON
        )
        about_btn.set_tooltip_text(t("btn_about"))
        about_btn.connect("clicked", self.on_about)
        hb.pack_end(about_btn)
        self.set_titlebar(hb)
        self.header = hb

    def _build_body(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        root.set_margin_top(18)
        root.set_margin_bottom(14)
        root.set_margin_start(22)
        root.set_margin_end(22)
        self.add(root)

        # Titel
        title = Gtk.Label(xalign=0)
        title.set_markup(f"<span>{GLib.markup_escape_text(t('subtitle'))}</span>")
        title.get_style_context().add_class("page-title")
        root.pack_start(title, False, False, 0)

        sep_top = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        root.pack_start(sep_top, False, False, 0)

        # Komponenten-Liste
        intro = Gtk.Label(xalign=0)
        intro.get_style_context().add_class("page-sub")
        intro.set_text(t("intro_header"))
        root.pack_start(intro, False, False, 0)

        comp_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        comp_box.set_margin_start(10)
        for key in ("comp_rgb", "comp_fan"):
            lbl = Gtk.Label(xalign=0)
            lbl.get_style_context().add_class("bullet")
            lbl.set_markup(f"  •  {GLib.markup_escape_text(t(key))}")
            comp_box.pack_start(lbl, False, False, 0)
        root.pack_start(comp_box, False, False, 0)

        # Sprache
        lang_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lang_row.set_margin_top(10)
        lang_lbl = Gtk.Label(label=t("lang_label"), xalign=0)
        lang_row.pack_start(lang_lbl, False, False, 0)

        self.rb_de = Gtk.RadioButton.new_with_label_from_widget(None, t("lang_de"))
        self.rb_en = Gtk.RadioButton.new_with_label_from_widget(self.rb_de, t("lang_en"))
        if self.script_lang == "en":
            self.rb_en.set_active(True)
        else:
            self.rb_de.set_active(True)
        self.rb_de.connect("toggled", self.on_lang_changed, "de")
        self.rb_en.connect("toggled", self.on_lang_changed, "en")
        lang_row.pack_start(self.rb_de, False, False, 0)
        lang_row.pack_start(self.rb_en, False, False, 0)
        root.pack_start(lang_row, False, False, 0)

        # Modul-Auswahl
        self.chk_rgb = Gtk.CheckButton(label=t("opt_rgb"))
        self.chk_rgb.set_active(True)
        root.pack_start(self.chk_rgb, False, False, 0)

        self.chk_fan = Gtk.CheckButton(label=t("opt_fan"))
        self.chk_fan.set_active(True)
        root.pack_start(self.chk_fan, False, False, 0)

        # Uninstall-Checkbox
        self.chk_uninstall = Gtk.CheckButton(label=t("opt_uninstall"))
        self.chk_uninstall.connect("toggled", self.on_uninstall_toggled)
        root.pack_start(self.chk_uninstall, False, False, 0)

        # Log-Header + ScrolledWindow (initial versteckt)
        self.log_header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.log_header_box.set_margin_top(8)
        self.log_status_icon = Gtk.Label()
        self.log_status_icon.set_markup("")
        log_header_lbl = Gtk.Label(xalign=0)
        log_header_lbl.get_style_context().add_class("section")
        log_header_lbl.set_text(t("log_header").upper())
        self.log_header_box.pack_start(log_header_lbl, False, False, 0)
        self.log_header_box.pack_start(self.log_status_icon, False, False, 0)
        root.pack_start(self.log_header_box, False, False, 0)
        self.log_header_box.hide()

        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.scrolled.set_min_content_height(220)
        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_monospace(True)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.log_view.get_style_context().add_class("log-view")
        self.scrolled.add(self.log_view)
        root.pack_start(self.scrolled, True, True, 0)
        self.scrolled.hide()

        # Status-Label
        self.status_label = Gtk.Label(xalign=0)
        self.status_label.get_style_context().add_class("status-idle")
        self.status_label.set_text(t("status_idle"))
        root.pack_start(self.status_label, False, False, 0)

        # Action-Buttons
        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        btn_row.set_margin_top(4)
        self.btn_close = Gtk.Button(label=t("btn_close"))
        self.btn_close.get_style_context().add_class("btn-secondary")
        self.btn_close.connect("clicked", lambda _w: self.close())
        btn_row.pack_start(self.btn_close, False, False, 0)

        spacer = Gtk.Box()
        btn_row.pack_start(spacer, True, True, 0)

        self.btn_install = Gtk.Button(label=t("btn_install"))
        self.btn_install.get_style_context().add_class("btn-primary")
        self.btn_install.connect("clicked", self.on_install_clicked)
        btn_row.pack_end(self.btn_install, False, False, 0)
        root.pack_start(btn_row, False, False, 0)

    # ── Event-Handler ─────────────────────────────────────────────────────
    def on_about(self, _btn):
        dlg = Gtk.AboutDialog(transient_for=self, modal=True)
        dlg.set_program_name(t("about_title"))
        dlg.set_version(VERSION)
        dlg.set_comments(t("about_comment"))
        dlg.set_license_type(Gtk.License.MIT_X11)
        dlg.run()
        dlg.destroy()

    def on_lang_changed(self, btn, lang):
        if btn.get_active():
            self.script_lang = lang

    def on_uninstall_toggled(self, chk):
        self.uninstall_mode = chk.get_active()
        ctx = self.btn_install.get_style_context()
        if self.uninstall_mode:
            self.btn_install.set_label(t("btn_uninstall"))
            ctx.remove_class("btn-primary")
            ctx.add_class("btn-danger")
        else:
            self.btn_install.set_label(t("btn_install"))
            ctx.remove_class("btn-danger")
            ctx.add_class("btn-primary")

    def on_install_clicked(self, _btn):
        # Modul-Auswahl prüfen
        rgb_active = self.chk_rgb.get_active()
        fan_active = self.chk_fan.get_active()
        if not rgb_active and not fan_active:
            self._error_dialog(
                t("err_no_module_title"),
                t("err_no_module"),
            )
            return

        # Vorab-Checks
        if not os.path.isfile(INSTALLER):
            self._error_dialog(
                t("err_no_installer_title"),
                t("err_no_installer", path=INSTALLER),
            )
            return
        if shutil.which("pkexec") is None:
            self._error_dialog(
                t("err_pkexec_missing_title"),
                t("err_pkexec_missing"),
            )
            return

        # UI → running
        self._set_running_ui(True)

        args = ["pkexec", "env", f"ROG_LANG={self.script_lang}",
                "bash", INSTALLER]
        if self.uninstall_mode:
            args.append("--uninstall")
        # Modul-Flags: beide aktiv → Default (kein Flag); sonst --rgb-only/--fan-only
        if rgb_active and not fan_active:
            args.append("--rgb-only")
        elif fan_active and not rgb_active:
            args.append("--fan-only")

        action_name = (t("action_uninstall") if self.uninstall_mode
                       else t("action_install"))
        self._append_log(t("log_starting", action=action_name,
                           cmd=" ".join(args)))

        self._start_subprocess(args, action_name)

    def _on_delete(self, _w, _evt):
        # Verhindere Schließen während Lauf
        return self.running

    # ── UI-State Helpers ──────────────────────────────────────────────────
    def _set_running_ui(self, running):
        self.running = running
        if running:
            self.set_deletable(False)
            # set_no_show_all(False) ZUERST — sonst ignoriert show_all() das Widget komplett
            # (GTK behandelt no_show_all=True als globalen Blocker, auch bei direktem Aufruf)
            self.log_header_box.set_no_show_all(False)
            self.scrolled.set_no_show_all(False)
            self.log_header_box.show_all()
            self.scrolled.show_all()
            # Fenster ggf. vergrößern
            w, h = self.get_size()
            if h < 720:
                self.resize(max(w, 720), 740)
            self.status_label.set_text(t("status_running"))
            self._set_status_class("status-run")
            self.log_status_icon.set_markup("")
        else:
            self.set_deletable(True)

        self.btn_install.set_sensitive(not running)
        self.btn_close.set_sensitive(not running)
        self.rb_de.set_sensitive(not running)
        self.rb_en.set_sensitive(not running)
        self.chk_rgb.set_sensitive(not running)
        self.chk_fan.set_sensitive(not running)
        self.chk_uninstall.set_sensitive(not running)

    def _set_status_class(self, cls):
        ctx = self.status_label.get_style_context()
        for c in ("status-idle", "status-run", "status-ok", "status-err"):
            ctx.remove_class(c)
        ctx.add_class(cls)

    def _append_log(self, text):
        clean = ANSI_RE.sub("", text)
        buf = self.log_view.get_buffer()
        end = buf.get_end_iter()
        buf.insert(end, clean)
        # Autoscroll
        mark = buf.create_mark(None, buf.get_end_iter(), False)
        self.log_view.scroll_to_mark(mark, 0.0, False, 0.0, 1.0)
        buf.delete_mark(mark)

    def _error_dialog(self, title, msg):
        dlg = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=title,
        )
        dlg.format_secondary_text(msg)
        dlg.run()
        dlg.destroy()

    # ── Subprocess-Handling ───────────────────────────────────────────────
    def _start_subprocess(self, args, action_name):
        try:
            # PYTHONUNBUFFERED + stdbuf erzwingt line-buffering bei child-Prozessen
            # damit Live-Output sofort in der GUI erscheint statt am Ende
            env = {**os.environ, "ROG_LANG": self.script_lang, "PYTHONUNBUFFERED": "1"}
            real_args = args
            # stdbuf nur wenn verfügbar (Coreutils, normal auf Linux Mint vorhanden)
            if shutil.which("stdbuf"):
                # Wir wrappen den Befehl nach 'pkexec env …' so dass bash line-buffered läuft
                # args: ['pkexec', 'env', 'ROG_LANG=...', 'bash', INSTALLER, ...]
                # → ['pkexec', 'env', 'ROG_LANG=...', 'stdbuf', '-oL', '-eL', 'bash', INSTALLER, ...]
                bash_idx = None
                for i, a in enumerate(args):
                    if a == "bash":
                        bash_idx = i
                        break
                if bash_idx is not None:
                    real_args = args[:bash_idx] + ["stdbuf", "-oL", "-eL"] + args[bash_idx:]
            proc = subprocess.Popen(
                real_args,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                env=env,
            )
        except Exception as e:
            self._append_log(f"\n[exec error] {e}\n")
            self._on_finished(-1, action_name)
            return

        def reader():
            try:
                assert proc.stdout is not None
                # readline statt for-loop liest auch unvollständige Zeilen früher
                while True:
                    line = proc.stdout.readline()
                    if not line:
                        break
                    GLib.idle_add(self._append_log, line)
            except Exception as e:
                GLib.idle_add(self._append_log, f"\n[read error] {e}\n")
            rc = proc.wait()
            GLib.idle_add(self._on_finished, rc, action_name)

        threading.Thread(target=reader, daemon=True).start()

    def _on_finished(self, returncode, action_name):
        self._set_running_ui(False)

        if returncode == 0:
            self._append_log(t("log_finished_ok", action=action_name))
            self.status_label.set_text(t("status_done_ok"))
            self._set_status_class("status-ok")
            self.log_status_icon.set_markup(
                "<span foreground='#a6e3a1' weight='bold'>  ✓</span>"
            )
        else:
            self._append_log(t("log_finished_err",
                               action=action_name, rc=returncode))
            self.status_label.set_text(t("status_done_err", rc=returncode))
            self._set_status_class("status-err")
            self.log_status_icon.set_markup(
                "<span foreground='#f38ba8' weight='bold'>  ✗</span>"
            )
            # Zum Ende scrollen
            buf = self.log_view.get_buffer()
            mark = buf.create_mark(None, buf.get_end_iter(), False)
            self.log_view.scroll_to_mark(mark, 0.0, False, 0.0, 1.0)
            buf.delete_mark(mark)

        # Close-Button → "Fertig"
        self.btn_close.set_label(t("btn_done"))
        ctx = self.btn_close.get_style_context()
        ctx.remove_class("btn-secondary")
        ctx.add_class("btn-success")
        # Install-Button bleibt deaktiviert
        self.btn_install.set_sensitive(False)
        return False


def _install_sigint_handler():
    # Sauberer Exit bei Ctrl+C im Terminal: GLib.unix_signal_add hängt sich
    # in den GTK-Mainloop ein, anstatt PyGObjects Default-Handler den
    # KeyboardInterrupt-Traceback aus _ossighelper.py werfen zu lassen.
    def _quit():
        Gtk.main_quit()
        return GLib.SOURCE_REMOVE
    try:
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, _quit)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, _quit)
    except (AttributeError, ValueError):
        # Fallback für sehr alte GLib-Versionen: Python-Handler
        signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())


def main():
    _load_css()
    win = InstallerWindow()
    win.connect("destroy", Gtk.main_quit)
    # set_no_show_all temporär aus, damit Initial-Layout korrekt ist
    win.scrolled.set_no_show_all(False)
    win.log_header_box.set_no_show_all(False)
    win.show_all()
    # Log-Bereich initial verstecken (nach show_all)
    win.scrolled.hide()
    win.log_header_box.hide()
    _install_sigint_handler()
    try:
        Gtk.main()
    except KeyboardInterrupt:
        # Belt-and-braces, falls SIGINT doch hochgereicht wird
        pass


if __name__ == "__main__":
    main()
