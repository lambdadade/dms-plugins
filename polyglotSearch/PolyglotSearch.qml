import QtQuick
import Quickshell
import qs.Services
import "translatorUtils.js" as TranslatorUtils

QtObject {
    id: root

    property var pluginService: null
    property string trigger: ">tr "

    signal itemsChanged()

    // cache key → translated string (or error message)
    property var translationCache: ({})
    // cache key → true while request is in flight
    property var pendingTranslations: ({})

    // Read the DeepL key stored by the polyglot widget plugin (shared setting)
    function getDeepLKey() {
        if (!pluginService) return "";
        return (pluginService.loadPluginData("polyglot", "deeplApiKey", "") || "").trim();
    }

    // ── Launcher contract ─────────────────────────────────────────────────────

    function getItems(query) {
        var q = (query || "").replace(/\s+/g, " ").trim();

        // No input: show usage hint + quick language reference
        if (!q) {
            var items = [{
                name: ">tr <lang> <text>",
                icon: "material:translate",
                comment: "e.g.  >tr fr Hello World  →  Bonjour tout le monde",
                action: "noop:",
                categories: ["PolyglotSearch"]
            }];
            var common = ["fr","en","es","de","it","pt","ru","ja","zh","ko","ar","nl","pl","uk","sv"];
            for (var i = 0; i < common.length; i++) {
                var code = common[i];
                items.push({
                    name: TranslatorUtils.getLanguageName(code),
                    icon: "material:language",
                    comment: ">tr " + code + " <text>",
                    action: "noop:",
                    categories: ["PolyglotSearch"]
                });
            }
            return items;
        }

        var parts = q.split(" ");
        var targetLang = TranslatorUtils.getLanguageCode(parts[0]);
        var text = parts.slice(1).join(" ").trim();

        // Language typed but no text yet
        if (!text) {
            return [{
                name: "Translate to " + TranslatorUtils.getLanguageName(targetLang) + "…",
                icon: "material:translate",
                comment: "Type the text to translate after the language code",
                action: "noop:",
                categories: ["PolyglotSearch"]
            }];
        }

        var cacheKey = targetLang + "|" + text;

        // Cached result
        if (translationCache[cacheKey] !== undefined) {
            var result = translationCache[cacheKey];
            return [{
                name: result,
                icon: "material:content_copy",
                comment: "→ " + TranslatorUtils.getLanguageName(targetLang) + "   (Enter to copy)",
                action: "copy:" + result,
                categories: ["PolyglotSearch"]
            }];
        }

        // Start request if not already in flight
        if (!pendingTranslations[cacheKey]) {
            pendingTranslations[cacheKey] = true;
            var deeplKey = getDeepLKey();
            if (deeplKey) {
                translateDeepL(text, targetLang, cacheKey, deeplKey);
            } else {
                translateGoogle(text, targetLang, cacheKey);
            }
        }

        return [{
            name: "Translating…",
            icon: "material:hourglass_empty",
            comment: text + "  →  " + TranslatorUtils.getLanguageName(targetLang),
            action: "noop:",
            categories: ["PolyglotSearch"]
        }];
    }

    function executeItem(item) {
        if (!item || !item.action) return;
        var colon = item.action.indexOf(":");
        if (colon < 0) return;
        var actionType = item.action.substring(0, colon);
        var actionData = item.action.substring(colon + 1);

        if (actionType === "copy" && actionData) {
            Quickshell.execDetached(["sh", "-c",
                "printf '%s' " + shellQuote(actionData) + " | wl-copy"]);
        }
        // "noop" → do nothing
    }

    // ── Translation backends ──────────────────────────────────────────────────

    function translateGoogle(text, targetLang, cacheKey) {
        // Capture QML property references as plain JS vars for use inside the async closure
        var cache = translationCache;
        var pending = pendingTranslations;
        var svc = pluginService;
        var url = "https://translate.google.com/translate_a/single?client=gtx&sl=auto&tl="
                  + encodeURIComponent(targetLang) + "&dt=t&q=" + encodeURIComponent(text);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            delete pending[cacheKey];
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    var out = "";
                    if (resp && resp[0]) {
                        for (var i = 0; i < resp[0].length; i++) {
                            if (resp[0][i] && resp[0][i][0]) out += resp[0][i][0];
                        }
                    }
                    cache[cacheKey] = out || "Translation error";
                } catch(e) {
                    cache[cacheKey] = "Parse error";
                }
            } else {
                cache[cacheKey] = "Connection error (" + xhr.status + ")";
            }
            if (svc) svc.notifyLauncherUpdate("polyglotSearch");
        };
        xhr.send();
    }

    function translateDeepL(text, targetLang, cacheKey, apiKey) {
        // Capture QML property references as plain JS vars for use inside the async closure
        var cache = translationCache;
        var pending = pendingTranslations;
        var svc = pluginService;
        var host = apiKey.endsWith(":fx") ? "api-free.deepl.com" : "api.deepl.com";
        var url = "https://" + host + "/v2/translate";
        var postData = "text=" + encodeURIComponent(text)
                     + "&target_lang=" + encodeURIComponent(targetLang.toUpperCase());
        var xhr = new XMLHttpRequest();
        xhr.open("POST", url);
        xhr.setRequestHeader("Authorization", "DeepL-Auth-Key " + apiKey);
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            delete pending[cacheKey];
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    var out = (resp && resp.translations && resp.translations[0]
                               && resp.translations[0].text) || "";
                    cache[cacheKey] = out || "Translation error";
                } catch(e) {
                    cache[cacheKey] = "Parse error";
                }
            } else if (xhr.status === 403) {
                cache[cacheKey] = "Invalid DeepL API key";
            } else {
                cache[cacheKey] = "Connection error (" + xhr.status + ")";
            }
            if (svc) svc.notifyLauncherUpdate("polyglotSearch");
        };
        xhr.send(postData);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function shellQuote(text) {
        return "'" + text.replace(/'/g, "'\\''") + "'";
    }
}
