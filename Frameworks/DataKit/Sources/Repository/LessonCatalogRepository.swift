import Foundation

public enum LessonCatalogError: Error {
    case missingResource
    case unsupportedVersion
    case invalidMetadata
    case duplicateIdentity
    case missingReference
}

public struct LessonCatalogRepository {
    private let data: Data?
    private let bundle: Bundle

    public init(bundle: Bundle? = nil) {
        self.bundle = bundle ?? Bundle(for: LessonBundleMarker.self)
        data = nil
    }

    public init(data: Data) {
        self.data = data
        bundle = Bundle(for: LessonBundleMarker.self)
    }

    public var attributionText: String {
        do {
            guard let url = bundle.url(forResource: "lesson-attribution", withExtension: "txt") else {
                throw LessonCatalogError.missingResource
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            guard Self.nonempty(text) else { throw LessonCatalogError.invalidMetadata }
            return text
        } catch {
            return "Lesson source notices could not be loaded. Reopen Sources to try again."
        }
    }

    public func materials() throws -> [StudyMaterial] {
        let contents: Data
        if let data { contents = data }
        else {
            guard let url = bundle.url(forResource: "lessons", withExtension: "json") else {
                throw LessonCatalogError.missingResource
            }
            contents = try Data(contentsOf: url)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resource = try decoder.decode(Resource.self, from: contents)
        guard resource.version == 1 else { throw LessonCatalogError.unsupportedVersion }
        guard resource.snapshot.count == 10, Self.hash(resource.commit, length: 40), !resource.materials.isEmpty else {
            throw LessonCatalogError.invalidMetadata
        }
        var identities = Set<String>()
        let grammarIDs = Set(resource.materials.filter { $0.kind == .grammar }.map(\.id))
        for material in resource.materials {
            _ = try StudyMaterialValidator.validate(material)
            guard identities.insert(material.id).inserted else { throw LessonCatalogError.duplicateIdentity }
            guard [.grammar, .sentence].contains(material.kind),
                  material.id.hasPrefix(material.kind.rawValue + ":"),
                  Self.nonempty(material.prompt), Self.nonempty(material.answer),
                  let level = material.level, ["N1", "N2", "N3", "N4", "N5"].contains(level),
                  let source = material.source, source.sourceID == material.id,
                  source.provider == "nihongo mono", source.license == "MIT",
                  source.snapshot == resource.snapshot, Self.nonempty(source.notice),
                  source.sourceURL.hasPrefix("https://github.com/stndaru/nihongo-mono/blob/\(resource.commit)/"),
                  Self.hash(source.textSHA256, length: 64),
                  material.createdAt == material.updatedAt,
                  material.structures.allSatisfy(Self.nonempty),
                  material.examples.allSatisfy({ Self.nonempty($0.japanese) && Self.nonempty($0.english) }) else {
                throw LessonCatalogError.invalidMetadata
            }
            guard material.relatedSourceIDs.allSatisfy(grammarIDs.contains),
                  source.parentIDs.allSatisfy(grammarIDs.contains) else { throw LessonCatalogError.missingReference }
            if material.kind == .sentence {
                guard !source.parentIDs.isEmpty, source.parentIDs == material.relatedSourceIDs else {
                    throw LessonCatalogError.missingReference
                }
            } else if material.examples.isEmpty { throw LessonCatalogError.invalidMetadata }
        }
        return resource.materials
    }

    private static func nonempty(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func hash(_ value: String, length: Int) -> Bool {
        value.count == length && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private struct Resource: Decodable {
        let version: Int
        let snapshot: String
        let commit: String
        let materials: [StudyMaterial]
    }
}

private final class LessonBundleMarker {}
