import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Common
import "fuzzy.js" as Fuzzy

QtObject {
    id: root

    property var pluginService: null
    property string trigger: "pw"

    // Backend toggles
    property bool useBitwarden: true
    property bool usePass: true

    // Enter key behaviour: "picker" | "password" | "userpass"
    property string enterAction: "picker"

    // Internal state
    property var _bwEntries: []   // [{id, name, user, folder}]
    property var _passEntries: [] // ["folder/name"]
    property string _prevId: ""   // most-recently-used bitwarden id

    signal itemsChanged()

    Component.onCompleted: {
        if (!pluginService) return;
        trigger       = pluginService.loadPluginData("dmsPasswords", "trigger",       "pw");
        useBitwarden  = pluginService.loadPluginData("dmsPasswords", "useBitwarden",  true);
        usePass       = pluginService.loadPluginData("dmsPasswords", "usePass",       true);
        enterAction   = pluginService.loadPluginData("dmsPasswords", "enterAction",   "picker");
        Qt.callLater(function() {
            if (useBitwarden) loadBitwarden();
            if (usePass)      loadPass();
        });
    }

    onTriggerChanged: {
        if (pluginService)
            pluginService.savePluginData("dmsPasswords", "trigger", trigger);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Shell helpers
    // ──────────────────────────────────────────────────────────────────────────

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getItems
    // ──────────────────────────────────────────────────────────────────────────

    function getItems(query) {
        const lq = query ? query.toLowerCase().trim() : "";
        let results = [];

        // ── Bitwarden entries ────────────────────────────────────────────────
        if (useBitwarden) {
            for (let i = 0; i < _bwEntries.length; i++) {
                const e = _bwEntries[i];
                const displayName = (e.folder ? e.folder + "/" : "") + e.name;
                const matchStr    = displayName.toLowerCase() + " " + (e.user || "").toLowerCase();

                if (!lq || matchStr.includes(lq)) {
                    results.push({
                        name:        displayName,
                        icon:        "material:shield",
                        comment:     e.user || "",
                        action:      "bw:" + e.id,
                        categories:  ["Passwords"],
                        keywords:    [e.name, e.user || ""],
                        _source:     "bw",
                        _id:         e.id,
                        _name:       e.name,
                        _user:       e.user || "",
                        _recent:     e.id === _prevId ? 0 : 1,
                        _score:      0
                    });
                }
            }
        }

        // ── Pass entries ─────────────────────────────────────────────────────
        if (usePass) {
            for (let i = 0; i < _passEntries.length; i++) {
                const entry = _passEntries[i];
                const score = lq ? Fuzzy.fuzzyScore(lq, entry) : 0;
                if (lq && score === null) continue;

                const lastSlash   = entry.lastIndexOf('/');
                const displayName = lastSlash >= 0 ? entry.substring(0, lastSlash) : entry;
                const user        = lastSlash >= 0 ? entry.substring(lastSlash + 1) : "";

                results.push({
                    name:       displayName || entry,
                    icon:       "material:vpn_key",
                    comment:    user || "",
                    action:     "pass:" + entry,
                    categories: ["Passwords"],
                    keywords:   [entry],
                    _source:    "pass",
                    _entry:     entry,
                    _recent:    1,
                    _score:     lq ? (score || 0) : 0
                });
            }
        }

        // ── Sync item (bitwarden only, when no query or query matches "sync") ─
        if (useBitwarden && (!lq || "sync".includes(lq))) {
            results.push({
                name:       "Sync Bitwarden",
                icon:       "material:sync",
                comment:    "Run rbw sync",
                action:     "sync:",
                categories: ["Passwords"],
                _source:    "meta",
                _recent:    2,
                _score:     0
            });
        }

        results.sort(function(a, b) {
            if (a._recent !== b._recent) return a._recent - b._recent;
            // Within pass entries, sort by fuzzy score when a query is active
            if (lq && a._source === "pass" && b._source === "pass")
                return b._score - a._score;
            return a.name.localeCompare(b.name);
        });

        return results.slice(0, 50);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // executeItem  (launcher closes after this; fuzzel picker appears if needed)
    // ──────────────────────────────────────────────────────────────────────────

    function executeItem(item) {
        if (!item || !item.action) return;

        if (item.action === "sync:") {
            syncBitwarden();
            return;
        }

        _prevId = item._id || "";

        switch (enterAction) {
        case "picker":
            openFieldPicker(item);
            break;
        case "password":
            typeField(item, "password");
            break;
        case "userpass":
            typeUsernamePassword(item);
            break;
        default:
            openFieldPicker(item);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Field picker via fuzzel --dmenu
    // ──────────────────────────────────────────────────────────────────────────

    function openFieldPicker(item) {
        const src = item._source;
        let script;

        if (src === "bw") {
            const id = item._id; // UUID – no special chars
            script = [
                "FIELD=$(printf '%s\\n' 'Type Password' 'Type Username' 'Type TOTP' 'Copy Password' 'Copy Username' 'Copy TOTP' | fuzzel --dmenu -p '🔑 ')",
                "[ -z \"$FIELD\" ] && exit 0",
                "case \"$FIELD\" in",
                "  'Type Password')  sleep 0.5 && _t=$(rbw get --field password '" + id + "' | tr -d '\\n') && ydotool type --clearmodifiers --delay=12 -- \"$_t\" ;;",
                "  'Type Username')  sleep 0.5 && _t=$(rbw get --field username '" + id + "' | tr -d '\\n') && ydotool type --clearmodifiers --delay=12 -- \"$_t\" ;;",
                "  'Type TOTP')      sleep 0.5 && _t=$(rbw get --field totp    '" + id + "' | tr -d '\\n') && ydotool type --clearmodifiers --delay=12 -- \"$_t\" ;;",
                "  'Copy Password')  rbw get --field password '" + id + "' | dms cl copy && sleep 45 && echo -n | wl-copy ;;",
                "  'Copy Username')  rbw get --field username '" + id + "' | dms cl copy && sleep 45 && echo -n | wl-copy ;;",
                "  'Copy TOTP')      rbw get --field totp    '" + id + "' | dms cl copy && sleep 45 && echo -n | wl-copy ;;",
                "esac"
            ].join("\n");
        } else {
            const eq = shellQuote(item._entry);
            script = [
                "FIELD=$(printf '%s\\n' 'Type Password' 'Type Username' 'Copy Password' | fuzzel --dmenu -p '🔑 ')",
                "[ -z \"$FIELD\" ] && exit 0",
                "case \"$FIELD\" in",
                "  'Type Password')  sleep 0.5 && _t=$(pass show " + eq + " | head -1 | tr -d '\\n') && ydotool type --clearmodifiers --delay=12 -- \"$_t\" ;;",
                "  'Type Username')  sleep 0.5 && _t=$(pass show " + eq + " | grep -i '^username:' | cut -d: -f2- | sed 's/^ *//;s/ *$//' | tr -d '\\n') && ydotool type --clearmodifiers --delay=12 -- \"$_t\" ;;",
                "  'Copy Password')  pass -c " + eq + " ;;",
                "esac"
            ].join("\n");
        }

        Quickshell.execDetached(["sh", "-c", script]);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Direct field actions (used by context menu and "password"/"userpass" modes)
    // ──────────────────────────────────────────────────────────────────────────

    function _ydotype(cmd) {
        // cmd must output the text to type on stdout (no trailing newline needed)
        return "sleep 0.8 && _t=$(" + cmd + " | tr -d '\\n') && ydotool type --clearmodifiers --delay=12 -- \"$_t\"";
    }

    function typeField(item, field) {
        if (item._source === "bw") {
            Quickshell.execDetached(["sh", "-c",
                _ydotype("rbw get --field " + field + " '" + item._id + "'")
            ]);
        } else {
            if (field === "password") {
                Quickshell.execDetached(["sh", "-c",
                    _ydotype("pass show " + shellQuote(item._entry) + " | head -1")
                ]);
            } else if (field === "username") {
                Quickshell.execDetached(["sh", "-c",
                    _ydotype("pass show " + shellQuote(item._entry) +
                    " | grep -i '^username:' | cut -d: -f2- | sed 's/^ *//;s/ *$//'")
                ]);
            } else if (field === "totp") {
                Quickshell.execDetached(["sh", "-c",
                    _ydotype("pass otp " + shellQuote(item._entry))
                ]);
            }
        }
    }

    function typeUsernamePassword(item) {
        if (item._source === "bw") {
            const id = item._id;
            Quickshell.execDetached(["sh", "-c",
                "sleep 0.8 && " +
                "_u=$(rbw get --field username '" + id + "' | tr -d '\\n') && " +
                "_p=$(rbw get --field password '" + id + "' | tr -d '\\n') && " +
                "ydotool type --clearmodifiers --delay=12 -- \"$_u\" && " +
                "ydotool key --clearmodifiers 15 && " +
                "ydotool type --clearmodifiers --delay=12 -- \"$_p\""
            ]);
        } else {
            // pass doesn't have a reliable username field – just type password
            typeField(item, "password");
        }
    }

    function copyField(item, field) {
        const label = item._name || item.name;
        if (item._source === "bw") {
            Quickshell.execDetached(["sh", "-c",
                "rbw get --field " + field + " '" + item._id + "' | dms cl copy && sleep 45 && echo -n | wl-copy"
            ]);
            ToastService.showInfo("Passwords", "Copied " + field + " of " + label + " · clears in 45s");
        } else {
            if (field === "password") {
                Quickshell.execDetached(["pass", "-c", item._entry]);
                ToastService.showInfo("Passwords", "Copied password of " + label);
            } else if (field === "username") {
                Quickshell.execDetached(["sh", "-c",
                    "pass show " + shellQuote(item._entry) +
                    " | grep -i '^username:' | cut -d: -f2- | sed 's/^ *//' | dms cl copy"
                ]);
                ToastService.showInfo("Passwords", "Copied username of " + label);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Context menu  (F10 / right-click – launcher stays open)
    // ──────────────────────────────────────────────────────────────────────────

    function getContextMenuActions(item) {
        if (!item || !item._source || item._source === "meta") return [];

        const src = item._source;
        const actions = [
            { icon: "keyboard",     text: I18n.tr("Type Password"),  action: function() { typeField(item, "password"); },  closeLauncher: true },
            { icon: "keyboard",     text: I18n.tr("Type Username"),  action: function() { typeField(item, "username"); },  closeLauncher: true }
        ];

        if (src === "bw")
            actions.push({ icon: "keyboard", text: I18n.tr("Type TOTP"), action: function() { typeField(item, "totp"); }, closeLauncher: true });

        if (src === "bw")
            actions.push({ icon: "keyboard", text: I18n.tr("Type Username + Password"), action: function() { typeUsernamePassword(item); }, closeLauncher: true });

        actions.push({ icon: "content_copy", text: I18n.tr("Copy Password"), action: function() { copyField(item, "password"); }, closeLauncher: true });
        actions.push({ icon: "content_copy", text: I18n.tr("Copy Username"), action: function() { copyField(item, "username"); }, closeLauncher: true });

        if (src === "bw")
            actions.push({ icon: "content_copy", text: I18n.tr("Copy TOTP"), action: function() { copyField(item, "totp"); }, closeLauncher: true });

        return actions;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Bitwarden loading (rbw)
    // ──────────────────────────────────────────────────────────────────────────

    function loadBitwarden() {
        bwListComp.createObject(root).running = true;
    }

    function syncBitwarden() {
        ToastService.showInfo("Passwords", "Syncing Bitwarden…");
        bwSyncComp.createObject(root).running = true;
    }

    property Component bwListComp: Component {
        Process {
            id: bwListProc
            running: false
            command: ["rbw", "list", "--raw"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        if (Array.isArray(data)) {
                            root._bwEntries = data;
                            root.itemsChanged();
                        }
                    } catch (e) {
                        console.error("[dmsPasswords] Failed to parse rbw output:", e);
                    }
                    bwListProc.destroy();
                }
            }

            onExited: code => {
                if (code !== 0) {
                    console.warn("[dmsPasswords] rbw list failed (exit " + code + "). Is rbw installed and unlocked?");
                    bwListProc.destroy();
                }
            }
        }
    }

    property Component bwSyncComp: Component {
        Process {
            id: bwSyncProc
            running: false
            command: ["rbw", "sync"]
            onExited: code => {
                if (code === 0) {
                    root.loadBitwarden();
                    ToastService.showInfo("Passwords", "Bitwarden synced");
                } else {
                    ToastService.showWarning("Passwords", "Bitwarden sync failed");
                }
                bwSyncProc.destroy();
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Password Store loading (pass / gpg)
    // ──────────────────────────────────────────────────────────────────────────

    function loadPass() {
        passIndexComp.createObject(root).running = true;
    }

    property Component passIndexComp: Component {
        Process {
            id: passIndexProc
            running: false
            command: ["sh", "-c",
                "cd \"${PASSWORD_STORE_DIR:-$HOME/.password-store}\" 2>/dev/null && " +
                "find . -name '*.gpg' -type f 2>/dev/null"
            ]

            stdout: SplitParser {
                onRead: function(line) {
                    let s = line.trim();
                    if (!s) return;
                    if (s.startsWith("./")) s = s.substring(2);
                    if (s.endsWith(".gpg")) s = s.substring(0, s.length - 4);
                    root._passEntries.push(s);
                }
            }

            onExited: code => {
                root._passEntries.sort();
                root.itemsChanged();
                passIndexProc.destroy();
            }
        }
    }
}
