import Foundation

struct PhoneticGroup: Identifiable {
    let id: UUID
    let wordMembers: [Word]

    static func groups(in words: [Word]) -> [PhoneticGroup] {
        let members = Dictionary(grouping: words.compactMap { word -> Word? in
            word.phoneticGroupId == nil ? nil : word
        }, by: { $0.phoneticGroupId! })
        return members.keys.sorted { $0.uuidString < $1.uuidString }.compactMap { id in
            guard let words = members[id], words.count > 1 else { return nil }
            return PhoneticGroup(id: id, wordMembers: words)
        }
    }
}

enum PhoneticGrouping {
    static func key(_ phonetic: String) -> String {
        phonetic.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
    }

    // Only new words and phonetic changes trigger matching, preserving manual exclusions on other saves.
    static func reconcile(_ incoming: [Word], previous: [Word]) -> [Word] {
        let oldWords = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        var words = incoming
        for index in words.indices {
            if let old = oldWords[words[index].id] {
                words[index].phoneticGroupId = old.phoneticGroupId
            }
        }
        let changedIDs = incoming.filter {
            oldWords[$0.id] == nil || oldWords[$0.id]?.Phonetic != $0.Phonetic
        }.map(\.id)
        for id in changedIDs {
            guard let index = words.firstIndex(where: { $0.id == id }) else { continue }
            words[index].phoneticGroupId = nil
            let phonetic = key(words[index].Phonetic)
            guard !phonetic.isEmpty else { continue }
            let matches = words.filter { $0.id != id && key($0.Phonetic) == phonetic }
            guard !matches.isEmpty else { continue }
            let existingGroups = Set(matches.compactMap(\.phoneticGroupId))
            let groupID = existingGroups.sorted { $0.uuidString < $1.uuidString }.first ?? UUID()
            let memberIDs = Set(matches.map(\.id)).union([id])
            for member in words.indices {
                if memberIDs.contains(words[member].id)
                    || words[member].phoneticGroupId.map({ existingGroups.contains($0) }) == true {
                    words[member].phoneticGroupId = groupID
                }
            }
        }
        return pruneSingletons(words)
    }

    static func setMembers(of wordID: UUID, selectedIDs: Set<UUID>, in incoming: [Word]) -> [Word] {
        var words = incoming
        guard let index = words.firstIndex(where: { $0.id == wordID }) else { return words }
        var selected = selectedIDs.intersection(Set(words.map(\.id))).subtracting([wordID])
        let previousGroup = words[index].phoneticGroupId
        let joinedGroups = Set(words.filter { selected.contains($0.id) }.compactMap(\.phoneticGroupId))
            .subtracting(previousGroup.map { [$0] } ?? [])
        selected.formUnion(words.filter {
            $0.phoneticGroupId.map { joinedGroups.contains($0) } == true
        }.map(\.id))
        if selected.isEmpty {
            words[index].phoneticGroupId = nil
        } else {
            let groupID = previousGroup ?? UUID()
            for member in words.indices {
                if words[member].id == wordID || selected.contains(words[member].id) {
                    words[member].phoneticGroupId = groupID
                } else if let previousGroup, words[member].phoneticGroupId == previousGroup {
                    words[member].phoneticGroupId = nil
                }
            }
        }
        return pruneSingletons(words)
    }

    private static func pruneSingletons(_ incoming: [Word]) -> [Word] {
        let counts = incoming.reduce(into: [UUID: Int]()) { counts, word in
            if let id = word.phoneticGroupId { counts[id, default: 0] += 1 }
        }
        return incoming.map { word in
            var word = word
            if let id = word.phoneticGroupId, counts[id, default: 0] < 2 {
                word.phoneticGroupId = nil
            }
            return word
        }
    }
}