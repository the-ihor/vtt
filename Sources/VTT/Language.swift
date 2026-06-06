import Carbon
import Foundation
import Speech

/// A selectable transcription language.
struct AppLanguage: Identifiable, Hashable, Sendable {
    /// ISO 639-1 code, used by the cloud APIs (e.g. "en", "uk").
    let code: String
    /// Representative BCP-47 locale, used by the Apple engines (e.g. "en-US").
    let locale: String
    /// English display name.
    let name: String

    var id: String { code }
}

enum Languages {
    /// Sentinel meaning "follow whatever keyboard is active when recording starts."
    static let auto = "auto"

    /// The full list offered in the user's language selector. These are the
    /// common languages supported across the cloud providers.
    static let all: [AppLanguage] = [
        .init(code: "en", locale: "en-US", name: "English"),
        .init(code: "es", locale: "es-ES", name: "Spanish"),
        .init(code: "fr", locale: "fr-FR", name: "French"),
        .init(code: "de", locale: "de-DE", name: "German"),
        .init(code: "it", locale: "it-IT", name: "Italian"),
        .init(code: "pt", locale: "pt-BR", name: "Portuguese"),
        .init(code: "nl", locale: "nl-NL", name: "Dutch"),
        .init(code: "ru", locale: "ru-RU", name: "Russian"),
        .init(code: "uk", locale: "uk-UA", name: "Ukrainian"),
        .init(code: "pl", locale: "pl-PL", name: "Polish"),
        .init(code: "tr", locale: "tr-TR", name: "Turkish"),
        .init(code: "sv", locale: "sv-SE", name: "Swedish"),
        .init(code: "da", locale: "da-DK", name: "Danish"),
        .init(code: "nb", locale: "nb-NO", name: "Norwegian"),
        .init(code: "fi", locale: "fi-FI", name: "Finnish"),
        .init(code: "cs", locale: "cs-CZ", name: "Czech"),
        .init(code: "ro", locale: "ro-RO", name: "Romanian"),
        .init(code: "el", locale: "el-GR", name: "Greek"),
        .init(code: "ar", locale: "ar-SA", name: "Arabic"),
        .init(code: "he", locale: "he-IL", name: "Hebrew"),
        .init(code: "hi", locale: "hi-IN", name: "Hindi"),
        .init(code: "zh", locale: "zh-CN", name: "Chinese"),
        .init(code: "ja", locale: "ja-JP", name: "Japanese"),
        .init(code: "ko", locale: "ko-KR", name: "Korean"),
        .init(code: "id", locale: "id-ID", name: "Indonesian"),
        .init(code: "vi", locale: "vi-VN", name: "Vietnamese"),
    ]

    /// Resolve any language code to an `AppLanguage` — a curated entry if known,
    /// otherwise one derived from the system's localized language name.
    static func named(_ code: String) -> AppLanguage {
        let base = String(code.split(separator: "-").first ?? Substring(code))
        if let known = all.first(where: { $0.code == base }) { return known }
        let name = Locale.current.localizedString(forLanguageCode: base)?.capitalized
            ?? base.uppercased()
        return AppLanguage(code: base, locale: code.contains("-") ? code : base, name: name)
    }

    /// The languages from the user's enabled macOS keyboard input sources,
    /// deduped, in input-source order. Falls back to the system default.
    static func keyboard() -> [AppLanguage] {
        var seen = Set<String>()
        var result: [AppLanguage] = []
        for code in KeyboardLanguages.codes() {
            let language = named(code)
            if seen.insert(language.code).inserted { result.append(language) }
        }
        return result.isEmpty ? [named(systemDefault)] : result
    }

    /// The system language if it's in the list, otherwise English.
    static var systemDefault: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return all.contains { $0.code == code } ? code : "en"
    }

    /// Languages a given provider can transcribe. Apple's on-device recognizer
    /// is queried for real; the others support the full common list.
    static func supported(by source: SpeechSource) -> [AppLanguage] {
        switch source {
        case .appleOnDevice:
            let codes = Set(SFSpeechRecognizer.supportedLocales().compactMap {
                $0.language.languageCode?.identifier
            })
            return all.filter { codes.contains($0.code) }
        case .appleSpeechAnalyzer, .deepgram, .elevenLabs, .openAI:
            return all
        }
    }

    static func isSupported(_ code: String, by source: SpeechSource) -> Bool {
        supported(by: source).contains { $0.code == code }
    }
}

/// Reads the user's enabled keyboard input-source languages from the system.
enum KeyboardLanguages {
    /// Primary language of the currently-active keyboard input source.
    static func currentCode() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return primaryLanguage(of: source)
    }

    static func codes() -> [String] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            return []
        }

        var codes: [String] = []
        for index in 0..<CFArrayGetCount(list) {
            let source = unsafeBitCast(CFArrayGetValueAtIndex(list, index), to: TISInputSource.self)
            guard let primary = primaryLanguage(of: source) else { continue }
            codes.append(primary)
        }
        return codes
    }

    private static func primaryLanguage(of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return nil
        }
        let languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue()
        guard CFArrayGetCount(languages) > 0 else { return nil }
        let value = unsafeBitCast(CFArrayGetValueAtIndex(languages, 0), to: CFString.self)
        return value as String
    }
}
