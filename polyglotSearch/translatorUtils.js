.pragma library

var languages = {
    "fr": {name: "french", aliases: ["french", "français", "fr"]},
    "en": {name: "english", aliases: ["english", "anglais", "en"]},
    "es": {name: "spanish", aliases: ["spanish", "espagnol", "es"]},
    "de": {name: "german", aliases: ["german", "allemand", "de"]},
    "it": {name: "italian", aliases: ["italian", "italien", "it"]},
    "pt": {name: "portuguese", aliases: ["portuguese", "portugais", "pt"]},
    "ru": {name: "russian", aliases: ["russian", "russe", "ru"]},
    "ja": {name: "japanese", aliases: ["japanese", "japonais", "ja"]},
    "zh": {name: "chinese", aliases: ["chinese", "chinois", "zh"]},
    "ko": {name: "korean", aliases: ["korean", "coréen", "ko"]},
    "ar": {name: "arabic", aliases: ["arabic", "arabe", "ar"]},
    "hi": {name: "hindi", aliases: ["hindi", "hi"]},
    "nl": {name: "dutch", aliases: ["dutch", "néerlandais", "hollandais", "nl"]},
    "pl": {name: "polish", aliases: ["polish", "polonais", "pl"]},
    "sv": {name: "swedish", aliases: ["swedish", "suédois", "sv"]},
    "da": {name: "danish", aliases: ["danish", "danois", "da"]},
    "no": {name: "norwegian", aliases: ["norwegian", "norvégien", "no"]},
    "fi": {name: "finnish", aliases: ["finnish", "finnois", "fi"]},
    "cs": {name: "czech", aliases: ["czech", "tchèque", "cs"]},
    "hu": {name: "hungarian", aliases: ["hungarian", "hongrois", "hu"]},
    "ro": {name: "romanian", aliases: ["romanian", "roumain", "ro"]},
    "tr": {name: "turkish", aliases: ["turkish", "turc", "tr"]},
    "uk": {name: "ukrainian", aliases: ["ukrainian", "ukrainien", "uk"]},
    "vi": {name: "vietnamese", aliases: ["vietnamese", "vietnamien", "vi"]},
    "th": {name: "thai", aliases: ["thai", "thaï", "th"]},
    "id": {name: "indonesian", aliases: ["indonesian", "indonésien", "id"]},
    "el": {name: "greek", aliases: ["greek", "grec", "el"]},
    "he": {name: "hebrew", aliases: ["hebrew", "hébreu", "he"]},
    "bg": {name: "bulgarian", aliases: ["bulgarian", "bulgare", "bg"]},
    "hr": {name: "croatian", aliases: ["croatian", "croate", "hr"]},
    "sr": {name: "serbian", aliases: ["serbian", "serbe", "sr"]},
    "sk": {name: "slovak", aliases: ["slovak", "slovaque", "sk"]},
    "sl": {name: "slovenian", aliases: ["slovenian", "slovène", "sl"]},
    "et": {name: "estonian", aliases: ["estonian", "estonien", "et"]},
    "lv": {name: "latvian", aliases: ["latvian", "letton", "lv"]},
    "lt": {name: "lithuanian", aliases: ["lithuanian", "lituanien", "lt"]},
    "ca": {name: "catalan", aliases: ["catalan", "ca"]},
    "is": {name: "icelandic", aliases: ["icelandic", "islandais", "is"]},
    "bn": {name: "bengali", aliases: ["bengali", "bn"]},
    "fa": {name: "persian", aliases: ["persian", "persan", "farsi", "fa"]},
    "sw": {name: "swahili", aliases: ["swahili", "sw"]},
    "ms": {name: "malay", aliases: ["malay", "malais", "ms"]},
    "af": {name: "afrikaans", aliases: ["afrikaans", "af"]}
};

function getLanguageCode(input) {
    if (!input || input.trim() === "") return "";
    var lower = input.toLowerCase();
    for (var code in languages) {
        if (languages[code].aliases.indexOf(lower) !== -1) return code;
    }
    return lower;
}

function getLanguageName(code) {
    var entry = languages[code];
    if (!entry) return code.toUpperCase();
    return entry.name.charAt(0).toUpperCase() + entry.name.slice(1);
}
