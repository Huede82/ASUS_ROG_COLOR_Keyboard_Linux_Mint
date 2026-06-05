#!/usr/bin/env python3
"""
ROG RGB GUI — Grafische Tastaturbeleuchtungs-Steuerung
ASUS ROG N-KEY Laptops unter Linux Mint / Ubuntu
"""

try:
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib
    import cairo
except ImportError:
    print("Fehlende Abhängigkeiten!")
    print("sudo apt install python3-gi gir1.2-gtk-3.0 python3-gi-cairo")
    import sys; sys.exit(1)

import subprocess, sys, json, threading, math, re, os
from pathlib import Path

# ── Pfade ─────────────────────────────────────────────────────────────────────
CONFIG_DIR      = Path.home() / ".config" / "rog-rgb"
CONFIG_FILE     = CONFIG_DIR / "gui_settings.json"
LAST_COLOR_FILE = CONFIG_DIR / "last_color"
SYSFS_BRIGHT    = Path("/sys/class/leds/asus::kbd_backlight/brightness")
SYSFS_MAX       = Path("/sys/class/leds/asus::kbd_backlight/max_brightness")
SCRIPT_PATH     = Path(__file__).resolve()

DEFAULT = {"effect": "static", "color": "#ff5500", "brightness": 3, "speed": 2, "language": "de"}

# ── Translations ──────────────────────────────────────────────────────────────
TRANSLATIONS = {
    "de": {
        "win_title":        "ROG RGB Steuerung",
        "hb_title":         "⚡  ROG RGB Steuerung",
        "hb_subtitle":      "ASUS N-KEY Keyboard",
        "live_label":       "Live",
        "live_tooltip":     "Änderungen sofort auf Tastatur übernehmen",
        "lang_btn":         "🌐 EN",
        "lang_tooltip":     "Switch to English",
        "card_color":       "🎨  FARBE",
        "card_bright":      "☀️  HELLIGKEIT",
        "card_effects":     "✨  EFFEKTE",
        "card_speed":       "⚡  GESCHWINDIGKEIT",
        "card_preview":     "🖥️  TASTATUR-VORSCHAU",
        "clr_tooltip":      "Klicken zum Öffnen des Farbwählers",
        "clr_pick_btn":     "🎨  Farbe wählen …",
        "presets_lbl":      "SCHNELLFARBEN",
        "bright_off":       "Aus",
        "bright_max":       "Max",
        "spd_slow":         "Langsam",
        "spd_mid":          "Mittel",
        "spd_fast":         "Schnell",
        "clr_dialog":       "Farbe wählen",
        "preview_click":    "Klicken zum Ändern",
        "status_ready":     "  Bereit",
        "status_applying":  "⏳  Wird angewendet …",
        "status_err":       "✗  Fehler – rogauracore erreichbar?",
        "status_reset":     "  Einstellungen zurückgesetzt",
        "btn_reset":        "↺  Zurücksetzen",
        "btn_reset_tip":    "Zuletzt gespeicherte Einstellungen laden",
        "btn_apply":        "▶  Anwenden",
        "btn_apply_tip":    "Einstellungen jetzt übernehmen und dauerhaft speichern",
        "err_notfound":     "rogauracore nicht gefunden",
        "err_notfound2":    "Bitte zuerst das Installations-Script ausführen:\nsudo bash install-rog-rgb.sh",
        "effects": [
            ("static",  "●  Statisch",    "Feste Farbe ohne Animation"),
            ("breathe", "◎  Atmen",       "Sanftes Ein- und Ausblenden"),
            ("rainbow", "◈  Regenbogen",  "Regenbogen-Farbverlauf über alle Tasten"),
            ("cycle",   "⟳  Farbzyklus",  "Automatischer Farbwechsel"),
            ("off",     "○  Ausschalten", "Beleuchtung komplett deaktivieren"),
        ],
    },
    "en": {
        "win_title":        "ROG RGB Control",
        "hb_title":         "⚡  ROG RGB Control",
        "hb_subtitle":      "ASUS N-KEY Keyboard",
        "live_label":       "Live",
        "live_tooltip":     "Apply changes to keyboard immediately",
        "lang_btn":         "🌐 DE",
        "lang_tooltip":     "Zu Deutsch wechseln",
        "card_color":       "🎨  COLOR",
        "card_bright":      "☀️  BRIGHTNESS",
        "card_effects":     "✨  EFFECTS",
        "card_speed":       "⚡  SPEED",
        "card_preview":     "🖥️  KEYBOARD PREVIEW",
        "clr_tooltip":      "Click to open color chooser",
        "clr_pick_btn":     "🎨  Choose color …",
        "presets_lbl":      "QUICK COLORS",
        "bright_off":       "Off",
        "bright_max":       "Max",
        "spd_slow":         "Slow",
        "spd_mid":          "Medium",
        "spd_fast":         "Fast",
        "clr_dialog":       "Choose color",
        "preview_click":    "Click to change",
        "status_ready":     "  Ready",
        "status_applying":  "⏳  Applying …",
        "status_err":       "✗  Error – rogauracore reachable?",
        "status_reset":     "  Settings reset",
        "btn_reset":        "↺  Reset",
        "btn_reset_tip":    "Load last saved settings",
        "btn_apply":        "▶  Apply",
        "btn_apply_tip":    "Apply and permanently save settings",
        "err_notfound":     "rogauracore not found",
        "err_notfound2":    "Please run the install script first:\nsudo bash install-rog-rgb.sh",
        "effects": [
            ("static",  "●  Static",      "Solid color, no animation"),
            ("breathe", "◎  Breathe",     "Soft fade in and out"),
            ("rainbow", "◈  Rainbow",     "Rainbow gradient across all keys"),
            ("cycle",   "⟳  Color Cycle", "Automatic color change"),
            ("off",     "○  Off",         "Disable backlight completely"),
        ],
    },
}

def _t(key, lang=None):
    """Return translated string for current language."""
    if lang is None:
        lang = _LANG
    return TRANSLATIONS.get(lang, TRANSLATIONS["de"]).get(key, key)

_LANG = "de"  # global, set from config at startup

# EFFECTS is now loaded from TRANSLATIONS at runtime via _t("effects")

PRESETS = [
    ("#ff0000", "Rot"),     ("#ff5500", "Orange"),  ("#ffcc00", "Gelb"),
    ("#00ff00", "Grün"),    ("#00ffff", "Cyan"),     ("#0066ff", "Blau"),
    ("#7700ff", "Lila"),    ("#ff00ff", "Magenta"),  ("#ffffff", "Weiß"),
    ("#ffaa00", "Gold"),    ("#ff6699", "Pink"),     ("#00ff88", "Türkis"),
]

# Tastaturlayout: (Anzahl Tasten, {Spalten-Index: Breitenfaktor})
KB_ROWS = [
    (14, {}),
    (14, {0: 1.45}),                        # Tab
    (13, {0: 1.75}),                        # Caps Lock
    (12, {0: 2.25, 11: 2.05}),              # Shift + Enter
    (8,  {0: 1.4, 1: 1.4, 3: 5.2, 6: 1.4, 7: 1.4}),  # Leertaste
]

# ── CSS (Catppuccin Mocha) ────────────────────────────────────────────────────
CSS = """
* { -gtk-outline-radius: 0; outline: none; }

window, .background {
    background-color: #1e1e2e;
}

headerbar, .titlebar {
    background-color: #181825;
    background-image: none;
    border-bottom: 1px solid #313244;
    box-shadow: none;
    padding: 4px 8px;
}
headerbar .title { color: #cba6f7; font-weight: bold; font-size: 14px; }
headerbar button {
    background: transparent; background-image: none;
    border: none; border-radius: 6px;
    color: #6c7086; padding: 4px 8px;
}
headerbar button:hover { background: #313244; background-image: none; color: #cdd6f4; }

label { color: #cdd6f4; }

.card {
    background-color: #181825;
    border-radius: 14px;
    border: 1px solid #313244;
    padding: 14px;
    margin: 5px;
}
.card-title {
    color: #6c7086;
    font-size: 10px;
    font-weight: bold;
    letter-spacing: 2px;
    margin-bottom: 4px;
}

/* Effekt-Buttons */
.eff-btn {
    background-color: #24273a; background-image: none;
    color: #a6adc8;
    border: 1px solid #363a4f; border-radius: 8px;
    padding: 10px 16px; font-size: 13px;
    transition: all 130ms ease;
}
.eff-btn:hover {
    background-color: #313244; background-image: none;
    color: #cdd6f4; border-color: #585b70;
}
.eff-btn.on {
    background-color: #8839ef; background-image: none;
    color: #ffffff; border-color: #8839ef; font-weight: bold;
}
.eff-btn:active { background-color: #7028d4; background-image: none; }

/* Speed-Buttons */
.spd-btn {
    background-color: #24273a; background-image: none;
    color: #a6adc8; border: 1px solid #363a4f;
    border-radius: 6px; padding: 7px 4px; font-size: 12px;
    transition: all 130ms ease;
}
.spd-btn:hover { background-color: #313244; background-image: none; color: #cdd6f4; }
.spd-btn.on {
    background-color: #1e66f5; background-image: none;
    color: #ffffff; border-color: #1e66f5; font-weight: bold;
}
.spd-btn:active { background-color: #1550cc; background-image: none; }

/* Anwenden-Button */
.apply-btn {
    background-color: #40a02b; background-image: none;
    color: #1e1e2e; border: none;
    border-radius: 10px; padding: 10px 28px;
    font-size: 14px; font-weight: bold; min-width: 130px;
}
.apply-btn:hover { background-color: #4caf33; background-image: none; }
.apply-btn:active { background-color: #338022; background-image: none; }

/* Reset-Button */
.reset-btn {
    background-color: #24273a; background-image: none;
    color: #a6adc8; border: 1px solid #363a4f;
    border-radius: 10px; padding: 10px 16px; font-size: 13px;
}
.reset-btn:hover { background-color: #313244; background-image: none; color: #cdd6f4; }
.reset-btn:active { background-color: #1e1e2e; background-image: none; }

/* Preset-Farb-Buttons */
.preset-btn {
    border-radius: 50%; padding: 0;
    border: 3px solid transparent;
    min-width: 30px; min-height: 30px;
    box-shadow: none; transition: border-color 100ms;
}
.preset-btn:hover { border-color: rgba(255,255,255,0.8); }
.preset-btn.on    { border-color: #ffffff; }

/* Helligkeit-Scale */
scale trough {
    min-height: 6px; border-radius: 3px;
    background-color: #313244; background-image: none; border: none;
}
scale slider {
    min-width: 20px; min-height: 20px;
    background-color: #cba6f7; background-image: none;
    border-radius: 50%; border: 3px solid #1e1e2e;
    box-shadow: 0 1px 5px rgba(0,0,0,0.7);
}
scale slider:hover { background-color: #d4bcff; background-image: none; }
scale marks label { color: #585b70; font-size: 10px; }

/* Hex-Eingabe */
entry {
    background-color: #24273a; background-image: none;
    color: #cdd6f4; border: 1px solid #363a4f;
    border-radius: 6px; padding: 6px 10px;
    font-family: monospace; font-size: 13px;
    caret-color: #cba6f7;
}
entry:focus { border-color: #8839ef; }
entry selection { background-color: #8839ef; color: #ffffff; }

/* Status */
.status         { color: #6c7086; font-size: 12px; }
.status-ok      { color: #a6e3a1; font-size: 12px; }
.status-err     { color: #f38ba8; font-size: 12px; }
.status-pending { color: #cba6f7; font-size: 12px; }

/* Helligkeit % */
.bright-pct { color: #cba6f7; font-weight: bold; font-size: 13px; min-width: 44px; }

/* Switch */
switch {
    background-color: #313244; background-image: none;
    border: 1px solid #45475a; border-radius: 14px;
    min-width: 42px; min-height: 22px; transition: background 200ms;
}
switch:checked { background-color: #8839ef; background-image: none; border-color: #8839ef; }
switch slider {
    background-color: #cdd6f4; background-image: none;
    border-radius: 50%; min-width: 16px; min-height: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.5); border: none;
}
.lbl-small { color: #a6adc8; font-size: 12px; }
"""


# ── Backends ──────────────────────────────────────────────────────────────────

def rogauracore(*args):
    try:
        r = subprocess.run(["rogauracore"] + list(args), capture_output=True, timeout=5)
        return r.returncode in (0, 17)
    except Exception:
        return False


def set_brightness(val):
    try:
        r = subprocess.run(
            ["sudo", "tee", str(SYSFS_BRIGHT)],
            input=str(val).encode(), capture_output=True, timeout=3
        )
        return r.returncode == 0
    except Exception:
        return False


def build_cmd(s):
    eff = s.get("effect", "static")
    col = s.get("color", "#ff5500").lstrip("#")
    spd = str(s.get("speed", 2))
    if eff == "static":  return ["single_static", col]
    if eff == "breathe": return ["single_breathing", col, "000000", spd]
    if eff == "rainbow": return ["rainbow_cycle", spd]
    if eff == "cycle":   return ["single_colorcycle", spd]
    if eff == "off":     return ["single_static", "000000"]
    return []


def do_apply(s):
    import time
    bri = 0 if s.get("effect") == "off" else s.get("brightness", 3)
    set_brightness(bri)
    cmd = build_cmd(s)
    ok = rogauracore(*cmd) if cmd else False
    if ok and s.get("effect") != "off":
        time.sleep(0.35)
        set_brightness(bri)
    return ok


def save_settings(s):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(s, f, indent=2)
    cmd = build_cmd(s)
    if cmd:
        LAST_COLOR_FILE.write_text(" ".join(cmd))


def load_settings():
    global _LANG
    try:
        with open(CONFIG_FILE) as f:
            data = json.load(f)
        for k, v in DEFAULT.items():
            data.setdefault(k, v)
        return data
    except Exception:
        return dict(DEFAULT)


def hue_to_rgb(h):
    h *= 6
    i = int(h); f = h - i
    if i == 0: return 1.0, f,   0.0
    if i == 1: return 1-f, 1.0, 0.0
    if i == 2: return 0.0, 1.0, f
    if i == 3: return 0.0, 1-f, 1.0
    if i == 4: return f,   0.0, 1.0
    return 1.0, 0.0, 1-f


# ── Hauptfenster ──────────────────────────────────────────────────────────────

class MainWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title=_t("win_title"))
        self.set_default_size(800, 640)
        self.set_resizable(False)

        # CSS einbinden
        prov = Gtk.CssProvider()
        prov.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.cfg   = load_settings()
        self._busy = False
        self._updating = False

        self._build_header()
        self._build_body()
        self.show_all()
        self._refresh_sensitivity()

    # ── Header ────────────────────────────────────────────────────────────────

    def _build_header(self):
        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        hb.set_title(_t("hb_title"))
        hb.set_subtitle(_t("hb_subtitle"))

        # Language toggle button
        lang_btn = Gtk.Button(label=_t("lang_btn"))
        lang_btn.set_tooltip_text(_t("lang_tooltip"))
        lang_btn.get_style_context().add_class("lbl-small")
        lang_btn.connect("clicked", self._on_lang_toggle)
        hb.pack_start(lang_btn)

        # Live-Schalter
        lbl = Gtk.Label(label=_t("live_label"))
        lbl.get_style_context().add_class("lbl-small")
        self.live_sw = Gtk.Switch()
        self.live_sw.set_active(True)
        self.live_sw.set_tooltip_text(_t("live_tooltip"))
        live_box = Gtk.Box(spacing=6, valign=Gtk.Align.CENTER)
        live_box.pack_start(lbl, False, False, 0)
        live_box.pack_start(self.live_sw, False, False, 0)
        hb.pack_end(live_box)

        self.set_titlebar(hb)

    # ── Body ──────────────────────────────────────────────────────────────────

    def _build_body(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        root.set_margin_start(8); root.set_margin_end(8)
        root.set_margin_top(8);   root.set_margin_bottom(8)
        self.add(root)

        # Mitte: Farbe/Helligkeit (links) + Effekte/Speed (rechts)
        mid = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        root.pack_start(mid, True, True, 0)
        mid.pack_start(self._build_color_panel(), False, False, 0)
        mid.pack_start(self._build_effect_panel(), True, True, 0)

        # Tastatur-Vorschau
        root.pack_start(self._build_preview(), False, False, 0)

        # Aktionsleiste
        root.pack_start(self._build_actionbar(), False, False, 0)

    # ── Linkes Panel: Farbe + Helligkeit ──────────────────────────────────────

    def _build_color_panel(self):
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        panel.set_size_request(330, -1)

        # ── Farb-Karte ─────────────────────────────────────────────────────────
        c_outer, c_inner = self._card(_t("card_color"))
        panel.pack_start(c_outer, True, True, 0)

        # Farbvorschau (klickbar)
        self.color_da = Gtk.DrawingArea()
        self.color_da.set_size_request(-1, 56)
        self.color_da.connect("draw", self._draw_color_preview)
        self.color_da.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.color_da.connect("button-press-event", self._open_color_dialog)
        self.color_da.set_tooltip_text(_t("clr_tooltip"))
        c_inner.pack_start(self.color_da, False, False, 0)

        # Farbe wählen Button
        pick_btn = Gtk.Button(label=_t("clr_pick_btn"))
        pick_btn.set_hexpand(True)
        pick_btn.connect("clicked", self._open_color_dialog)
        c_inner.pack_start(pick_btn, False, False, 6)

        # Hex-Eingabe
        hex_row = Gtk.Box(spacing=6)
        hex_lbl = Gtk.Label(label="#")
        hex_lbl.get_style_context().add_class("lbl-small")
        self.hex_entry = Gtk.Entry()
        self.hex_entry.set_max_length(6)
        self.hex_entry.set_width_chars(8)
        self.hex_entry.set_placeholder_text("ff5500")
        self.hex_entry.set_text(self.cfg.get("color", "#ff5500").lstrip("#"))
        self.hex_entry.connect("activate", self._on_hex_enter)
        self.hex_entry.connect("focus-out-event", self._on_hex_enter)
        hex_row.pack_start(hex_lbl, False, False, 0)
        hex_row.pack_start(self.hex_entry, True, True, 0)
        c_inner.pack_start(hex_row, False, False, 0)

        # Preset-Palette
        preset_lbl = Gtk.Label(label=_t("presets_lbl"))
        preset_lbl.get_style_context().add_class("card-title")
        preset_lbl.set_xalign(0)
        preset_lbl.set_margin_top(10)
        c_inner.pack_start(preset_lbl, False, False, 0)

        flow = Gtk.FlowBox()
        flow.set_max_children_per_line(6)
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_column_spacing(5); flow.set_row_spacing(5)
        self._preset_btns = []
        for hex_c, name in PRESETS:
            btn = self._make_preset_btn(hex_c, name)
            flow.add(btn)
            self._preset_btns.append((btn, hex_c))
        c_inner.pack_start(flow, False, False, 4)

        # ── Helligkeit-Karte ────────────────────────────────────────────────────
        b_outer, b_inner = self._card(_t("card_bright"))
        panel.pack_start(b_outer, False, False, 0)

        bright_row = Gtk.Box(spacing=10)
        self.bright_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 3, 1)
        self.bright_scale.set_value(self.cfg.get("brightness", 3))
        self.bright_scale.set_draw_value(False)
        self.bright_scale.set_hexpand(True)
        self.bright_scale.add_mark(0, Gtk.PositionType.BOTTOM, _t("bright_off"))
        self.bright_scale.add_mark(3, Gtk.PositionType.BOTTOM, _t("bright_max"))
        self.bright_scale.connect("value-changed", self._on_brightness)

        self.bright_lbl = Gtk.Label()
        self.bright_lbl.get_style_context().add_class("bright-pct")
        self.bright_lbl.set_size_request(48, -1)
        self.bright_lbl.set_xalign(1)
        self._update_bright_lbl(self.cfg.get("brightness", 3))

        bright_row.pack_start(self.bright_scale, True, True, 0)
        bright_row.pack_start(self.bright_lbl, False, False, 0)
        b_inner.pack_start(bright_row, False, False, 0)

        return panel

    # ── Rechtes Panel: Effekte + Geschwindigkeit ──────────────────────────────

    def _build_effect_panel(self):
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # ── Effekte ─────────────────────────────────────────────────────────────
        e_outer, e_inner = self._card(_t("card_effects"))
        panel.pack_start(e_outer, True, True, 0)

        self.eff_btns = {}
        cur = self.cfg.get("effect", "static")
        for eff_id, label, tooltip in _t("effects"):
            btn = Gtk.ToggleButton(label=label)
            btn.get_style_context().add_class("eff-btn")
            btn.set_tooltip_text(tooltip)
            btn.set_active(eff_id == cur)
            if eff_id == cur:
                btn.get_style_context().add_class("on")
            btn.connect("toggled", self._on_effect_toggle, eff_id)
            e_inner.pack_start(btn, False, False, 2)
            self.eff_btns[eff_id] = btn

        # ── Geschwindigkeit ──────────────────────────────────────────────────────
        s_outer, s_inner = self._card(_t("card_speed"))
        panel.pack_start(s_outer, False, False, 0)

        spd_box = Gtk.Box(spacing=6, homogeneous=True)
        self.spd_btns = {}
        cur_spd = self.cfg.get("speed", 2)
        for v, name in [(1, _t("spd_slow")), (2, _t("spd_mid")), (3, _t("spd_fast"))]:
            btn = Gtk.ToggleButton(label=name)
            btn.get_style_context().add_class("spd-btn")
            btn.set_active(v == cur_spd)
            if v == cur_spd:
                btn.get_style_context().add_class("on")
            btn.connect("toggled", self._on_speed_toggle, v)
            spd_box.pack_start(btn, True, True, 0)
            self.spd_btns[v] = btn
        s_inner.pack_start(spd_box, False, False, 0)

        return panel

    # ── Tastatur-Vorschau ─────────────────────────────────────────────────────

    def _build_preview(self):
        p_outer, p_inner = self._card(_t("card_preview"))
        self.kbd_da = Gtk.DrawingArea()
        self.kbd_da.set_size_request(-1, 90)
        self.kbd_da.connect("draw", self._draw_keyboard)
        p_inner.pack_start(self.kbd_da, True, True, 0)
        return p_outer

    # ── Aktionsleiste ─────────────────────────────────────────────────────────

    def _build_actionbar(self):
        bar = Gtk.Box(spacing=10)
        bar.set_margin_top(4)

        self.status_lbl = Gtk.Label(label=_t("status_ready"))
        self.status_lbl.get_style_context().add_class("status")
        self.status_lbl.set_xalign(0)

        reset_btn = Gtk.Button(label=_t("btn_reset"))
        reset_btn.get_style_context().add_class("reset-btn")
        reset_btn.set_tooltip_text(_t("btn_reset_tip"))
        reset_btn.connect("clicked", self._on_reset)

        apply_btn = Gtk.Button(label=_t("btn_apply"))
        apply_btn.get_style_context().add_class("apply-btn")
        apply_btn.set_tooltip_text(_t("btn_apply_tip"))
        apply_btn.connect("clicked", self._on_apply)

        bar.pack_start(self.status_lbl, True, True, 6)
        bar.pack_end(apply_btn, False, False, 0)
        bar.pack_end(reset_btn, False, False, 0)
        return bar

    # ── Hilfsmethoden ─────────────────────────────────────────────────────────

    def _card(self, title):
        """Erstellt eine styled Karten-Box mit Titel; gibt (outer, inner) zurück."""
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        outer.get_style_context().add_class("card")
        lbl = Gtk.Label(label=title)
        lbl.get_style_context().add_class("card-title")
        lbl.set_xalign(0)
        outer.pack_start(lbl, False, False, 0)
        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        outer.pack_start(inner, True, True, 0)
        return outer, inner

    def _make_preset_btn(self, hex_color, name):
        btn = Gtk.Button()
        btn.get_style_context().add_class("preset-btn")
        btn.set_tooltip_text(name)
        btn.set_size_request(30, 30)
        prov = Gtk.CssProvider()
        prov.load_from_data(
            f"button {{ background-color: {hex_color}; background-image: none; "
            f"border-color: transparent; }}".encode()
        )
        btn.get_style_context().add_provider(
            prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
        )
        btn.connect("clicked", self._on_preset, hex_color)
        return btn

    def _rgba_from_cfg(self):
        c = Gdk.RGBA()
        c.parse(self.cfg.get("color", "#ff5500"))
        return c

    def _update_bright_lbl(self, val):
        val = int(val)
        pct = {0: _t("bright_off"), 1: " 33%", 2: " 66%", 3: "100%"}
        self.bright_lbl.set_text(pct.get(val, f"{val}"))

    def _refresh_sensitivity(self):
        eff = self.cfg.get("effect", "static")
        needs_speed = eff in ("breathe", "rainbow", "cycle")
        needs_color = eff in ("static", "breathe")
        for b in self.spd_btns.values():
            b.set_sensitive(needs_speed)
        self.color_da.set_sensitive(needs_color)
        self.hex_entry.set_sensitive(needs_color)

    def _set_status(self, msg, cls="status"):
        def _do():
            self.status_lbl.set_text(msg)
            ctx = self.status_lbl.get_style_context()
            for c in ("status", "status-ok", "status-err", "status-pending"):
                ctx.remove_class(c)
            ctx.add_class(cls)
            return False
        GLib.idle_add(_do)

    # ── Draw-Callbacks ────────────────────────────────────────────────────────

    def _draw_color_preview(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        eff = self.cfg.get("effect", "static")

        if eff == "off":
            cr.set_source_rgb(0.08, 0.08, 0.10)
            self._rrect(cr, 0, 0, w, h, 8); cr.fill()
        elif eff in ("rainbow", "cycle"):
            self._paint_rainbow(cr, 0, 0, w, h, 8)
        else:
            c = self._rgba_from_cfg()
            cr.set_source_rgb(c.red, c.green, c.blue)
            self._rrect(cr, 0, 0, w, h, 8); cr.fill()

        # Border
        cr.set_source_rgba(1, 1, 1, 0.12)
        cr.set_line_width(1)
        self._rrect(cr, 0.5, 0.5, w - 1, h - 1, 8)
        cr.stroke()

        # Hinweistext
        cr.set_source_rgba(1, 1, 1, 0.55)
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        cr.set_font_size(11)
        txt = _t("preview_click")
        ext = cr.text_extents(txt)
        cr.move_to((w - ext.width) / 2, (h + ext.height) / 2)
        cr.show_text(txt)

    def _draw_keyboard(self, widget, cr):
        w  = widget.get_allocated_width()
        h  = widget.get_allocated_height()
        eff = self.cfg.get("effect", "static")
        bri = self.cfg.get("brightness", 3) / 3.0
        c   = self._rgba_from_cfg()
        pad = 10

        # Gehäuse
        cr.set_source_rgb(0.09, 0.09, 0.13)
        cr.rectangle(0, 0, w, h); cr.fill()
        cr.set_source_rgba(0.15, 0.15, 0.22, 1)
        self._rrect(cr, pad, pad, w - 2*pad, h - 2*pad, 10); cr.fill()

        # Tasten zeichnen
        kaw = w - 2*pad - 16
        kah = h - 2*pad - 14
        row_h   = (kah - (len(KB_ROWS) - 1) * 3) / len(KB_ROWS)
        base_kw = kaw / 15.0

        for ri, (n_keys, overrides) in enumerate(KB_ROWS):
            y = pad + 7 + ri * (row_h + 3)
            x = pad + 8
            for ki in range(n_keys):
                factor = overrides.get(ki, 1.0)
                kw = base_kw * factor
                m = 1.5

                if eff == "off":
                    cr.set_source_rgba(0.12, 0.12, 0.16, 1)
                elif eff in ("rainbow", "cycle"):
                    hue = ((x - pad - 8) / kaw + ri * 0.07) % 1.0
                    r, g, b = hue_to_rgb(hue)
                    cr.set_source_rgba(r * bri, g * bri, b * bri, 1)
                else:
                    cr.set_source_rgba(c.red * bri, c.green * bri, c.blue * bri, 1)

                self._rrect(cr, x + m, y + m, kw - 2*m, row_h - 2*m, 2.5)
                cr.fill()

                # Glanzlicht oben
                cr.set_source_rgba(1, 1, 1, 0.07)
                self._rrect(cr, x + m, y + m, kw - 2*m, (row_h - 2*m) * 0.38, 2.5)
                cr.fill()

                x += kw + 2.2

    def _paint_rainbow(self, cr, x, y, w, h, radius):
        pat = cairo.LinearGradient(x, 0, x + w, 0)
        stops = [
            (0.00, "#ff0000"), (0.14, "#ff8800"), (0.28, "#ffff00"),
            (0.42, "#00ff00"), (0.57, "#00ffff"), (0.71, "#0066ff"),
            (0.85, "#aa00ff"), (1.00, "#ff0000"),
        ]
        for pos, col in stops:
            r = int(col[1:3], 16) / 255
            g = int(col[3:5], 16) / 255
            b = int(col[5:7], 16) / 255
            pat.add_color_stop_rgb(pos, r, g, b)
        self._rrect(cr, x, y, w, h, radius)
        cr.set_source(pat); cr.fill()

    def _rrect(self, cr, x, y, w, h, r):
        r = min(r, w / 2, h / 2)
        cr.move_to(x + r, y)
        cr.line_to(x + w - r, y)
        cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
        cr.line_to(x + w, y + h - r)
        cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
        cr.line_to(x + r, y + h)
        cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
        cr.line_to(x, y + r)
        cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
        cr.close_path()

    # ── Signal-Handler ────────────────────────────────────────────────────────

    def _open_color_dialog(self, *_):
        if self.cfg.get("effect") not in ("static", "breathe"):
            return
        dlg = Gtk.ColorChooserDialog(
            title=_t("clr_dialog"), parent=self, use_alpha=False
        )
        dlg.set_rgba(self._rgba_from_cfg())

        # Palette einfügen
        palette = []
        for hex_c, _ in PRESETS:
            rgba = Gdk.RGBA(); rgba.parse(hex_c)
            palette.append(rgba)
        dlg.add_palette(Gtk.Orientation.HORIZONTAL, 6, palette)

        if dlg.run() == Gtk.ResponseType.OK:
            rgba = dlg.get_rgba()
            hex_c = "#{:02x}{:02x}{:02x}".format(
                int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255)
            )
            self._set_color(hex_c)
        dlg.destroy()

    def _on_hex_enter(self, widget, *_):
        txt = self.hex_entry.get_text().strip().lstrip("#")
        if re.match(r'^[0-9a-fA-F]{6}$', txt):
            self._set_color("#" + txt.lower())

    def _set_color(self, hex_c):
        self.cfg["color"] = hex_c
        self._updating = True
        self.hex_entry.set_text(hex_c.lstrip("#"))
        self._updating = False
        self.color_da.queue_draw()
        self.kbd_da.queue_draw()
        if self.live_sw.get_active():
            self._do_apply()

    def _on_preset(self, btn, hex_c):
        # Aktuelle Vorauswahl-Markierung entfernen
        for b, _ in self._preset_btns:
            b.get_style_context().remove_class("on")
        btn.get_style_context().add_class("on")
        self._set_color(hex_c)

    def _on_effect_toggle(self, btn, eff_id):
        if not btn.get_active():
            return
        if self._updating:
            return
        self._updating = True
        # Alle anderen deaktivieren
        for eid, b in self.eff_btns.items():
            if eid != eff_id:
                b.set_active(False)
                b.get_style_context().remove_class("on")
        btn.get_style_context().add_class("on")
        self._updating = False

        self.cfg["effect"] = eff_id
        self._refresh_sensitivity()
        self.color_da.queue_draw()
        self.kbd_da.queue_draw()
        if self.live_sw.get_active():
            self._do_apply()

    def _on_speed_toggle(self, btn, spd):
        if not btn.get_active() or self._updating:
            return
        self._updating = True
        for v, b in self.spd_btns.items():
            if v != spd:
                b.set_active(False)
                b.get_style_context().remove_class("on")
        btn.get_style_context().add_class("on")
        self._updating = False
        self.cfg["speed"] = spd
        if self.live_sw.get_active():
            self._do_apply()

    def _on_brightness(self, scale):
        if self._updating:
            return
        val = int(scale.get_value())
        self.cfg["brightness"] = val
        self._update_bright_lbl(val)
        self.kbd_da.queue_draw()
        if self.live_sw.get_active():
            self._do_apply()

    def _on_apply(self, *_):
        self._do_apply(force=True)

    def _on_lang_toggle(self, btn):
        global _LANG
        _LANG = "en" if _LANG == "de" else "de"
        self.cfg["language"] = _LANG
        save_settings(self.cfg)
        # Restart the app to re-render all labels
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def _on_reset(self, *_):
        self.cfg = load_settings()
        self._updating = True

        self.bright_scale.set_value(self.cfg.get("brightness", 3))
        self._update_bright_lbl(self.cfg.get("brightness", 3))

        cur = self.cfg.get("effect", "static")
        for eid, b in self.eff_btns.items():
            active = (eid == cur)
            b.set_active(active)
            ctx = b.get_style_context()
            ctx.add_class("on") if active else ctx.remove_class("on")

        cur_spd = self.cfg.get("speed", 2)
        for v, b in self.spd_btns.items():
            active = (v == cur_spd)
            b.set_active(active)
            ctx = b.get_style_context()
            ctx.add_class("on") if active else ctx.remove_class("on")

        self.hex_entry.set_text(self.cfg.get("color", "#ff5500").lstrip("#"))
        self._updating = False

        self._refresh_sensitivity()
        self.color_da.queue_draw()
        self.kbd_da.queue_draw()
        self._set_status(_t("status_reset"), "status")

    # ── Anwenden (Thread) ─────────────────────────────────────────────────────

    def _do_apply(self, force=False):
        if self._busy and not force:
            return
        self._busy = True
        self._set_status(_t("status_applying"), "status-pending")
        cfg_snap = dict(self.cfg)

        def worker():
            ok = do_apply(cfg_snap)
            save_settings(cfg_snap)
            if ok:
                label = next((l for i, l, _ in _t("effects") if i == cfg_snap.get("effect")), "?")
                self._set_status(f"✓  {label.strip()}", "status-ok")
            else:
                self._set_status(_t("status_err"), "status-err")
            self._busy = False
            GLib.idle_add(self.kbd_da.queue_draw)

        threading.Thread(target=worker, daemon=True).start()


# ── GTK Application ───────────────────────────────────────────────────────────

class ROGApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.rogscripts.rgb")

    def do_activate(self):
        MainWindow(self).present()


# ── .desktop Datei anlegen (Anwendungsmenü) ───────────────────────────────────

def install_desktop_entry():
    desktop_dir = Path.home() / ".local" / "share" / "applications"
    desktop_dir.mkdir(parents=True, exist_ok=True)
    desktop_file = desktop_dir / "rog-rgb-gui.desktop"
    content = f"""[Desktop Entry]
Name=ROG RGB Steuerung
Comment=ASUS ROG N-KEY Tastaturbeleuchtung steuern
Exec=python3 {SCRIPT_PATH}
Icon=preferences-color
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
Keywords=asus;rog;rgb;keyboard;tastatur;beleuchtung;
StartupNotify=true
"""
    desktop_file.write_text(content)
    try:
        subprocess.run(["update-desktop-database", str(desktop_dir)],
                       capture_output=True, check=False)
    except Exception:
        pass


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # rogauracore prüfen
    if subprocess.run(["which", "rogauracore"], capture_output=True).returncode != 0:
        dlg = Gtk.MessageDialog(
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=_t("err_notfound"),
            secondary_text=_t("err_notfound2")
        )
        dlg.run(); dlg.destroy(); sys.exit(1)

    # .desktop Eintrag beim ersten Start anlegen
    install_desktop_entry()

    ROGApp().run(sys.argv)
