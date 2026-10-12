import SwiftUI

struct WordsCollectionView: View {
    @AppStorage("collectionStudyKind") private var kind: StudyKind = .words
    @State private var query = ""
    var body: some View {
        Group {
            switch kind {
            case .words: AppComposer.shared.makeCollectionKotobaView(query: $query)
            case .kanji: AppComposer.shared.makeCollectionKanjiView(query: $query)
            case .grammar, .sentences, .cards: AppComposer.shared.makeMaterialLibraryView(kind: kind.savedKind).id(kind)
            }
        }.background(Forest.canvas)
    }
}

struct CollectionScreenHeader: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var textSize
    @AppStorage("collectionStudyKind") private var kind: StudyKind = .words
    @Binding var query: String
    var onReview: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.l) {
            (textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Forest.Space.s)) : AnyLayout(HStackLayout(alignment: .center, spacing: Forest.Space.m))) {
                ScreenHeader(title: "Collection")
                if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
                Menu("Options") {
                    Button("Study lists") { router.push(.studyLists, hideNavBar: false) }
                    if kind == .words { Button("Browse dictionary") { router.push(.dictionary, hideNavBar: false) } }
                    Button("Practice difficult items") { router.push(.difficult, hideNavBar: false) }
                    Button("Lessons") { router.push(.lessons, hideNavBar: false) }
                    Button("Learning practice") { router.push(.learningPractice, hideNavBar: false) }
                }.foregroundStyle(Forest.ink).frame(minWidth: 44, minHeight: 44)
            }
            (textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Forest.Space.s)) : AnyLayout(HStackLayout(spacing: Forest.Space.m))) {
                StudyKindPicker(selection: $kind, compact: true)
                if !textSize.isAccessibilitySize { Spacer(minLength: 0) }
                if let onReview {
                    Button("Review \(kind == .words ? "words" : kind == .kanji ? "kanji" : "items")", action: onReview)
                        .font(.body.weight(.semibold)).foregroundStyle(Forest.ink).frame(minHeight: 44)
                }
            }
            searchField
        }.foregroundStyle(Forest.ink)
    }
    private var searchField: some View {
        HStack(spacing: Forest.Space.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Forest.inkMuted)
                .accessibilityHidden(true)
            TextField(
                "Search",
                text: $query,
                prompt: Text("Japanese, reading or English").foregroundStyle(Forest.inkMuted)
            )
                .foregroundStyle(Forest.ink)
                .padding(.vertical, Forest.Space.s)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Forest.inkMuted)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Forest.Space.m)
        .frame(minHeight: 44)
        .background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Forest.Radius.card)
                .strokeBorder(Forest.line)
        }
    }
}
