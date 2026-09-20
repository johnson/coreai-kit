// CJKTokenSplit.swift — shared multi-char CJK token -> single-char id expansion,
// used by both VoxCPMTTS (0.5B) and VoxCPM2TTS (2B). Both models were trained
// with mask_multichar_chinese_tokens (OpenBMB/VoxCPM utils.py, and
// openbmb/VoxCPM2 tokenization_voxcpm2.py), so multi-character Chinese tokens
// from the stock Llama-fast tokenizer are out-of-distribution and yield
// garbled, unintelligible Chinese audio.

import Foundation

/// Splits multi-character CJK tokens into their single-character token ids.
enum CJKTokenSplit {
    /// Builds the multi-char CJK token -> single-char ids map from
    /// tokenizer.json: every vocab entry whose text (sans the U+2581 word
    /// marker) is >= 2 CJK characters is expanded to the ids of its individual
    /// characters. Tokens whose characters are not themselves in the vocab are
    /// left unsplit (the official code makes the same check against unk).
    static func buildMap(tokenizerDir: URL) -> [Int: [Int]] {
        guard let data = try? Data(contentsOf: tokenizerDir.appendingPathComponent("tokenizer.json")),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = root["model"] as? [String: Any],
              let vocab = model["vocab"] as? [String: Int] else { return [:] }
        var map: [Int: [Int]] = [:]
        for (token, tid) in vocab {
            let clean = token.replacingOccurrences(of: "\u{2581}", with: "")
            guard clean.count >= 2, clean.allSatisfy(isCJK) else { continue }
            let charIDs = clean.compactMap { vocab[String($0)] }
            guard charIDs.count == clean.count else { continue }
            map[tid] = charIDs
        }
        return map
    }

    /// CJK ranges per the official tokenizer: Unified + Ext-A + Compat + Ext-B.
    static func isCJK(_ c: Character) -> Bool {
        c.unicodeScalars.count == 1 && c.unicodeScalars.allSatisfy { s in
            (s.value >= 0x4E00 && s.value <= 0x9FFF)
                || (s.value >= 0x3400 && s.value <= 0x4DBF)
                || (s.value >= 0xF900 && s.value <= 0xFAFF)
                || (s.value >= 0x20000 && s.value <= 0x2A6DF)
        }
    }
}
