//
//  ForestComponents.swift
//  SwiftUIApps
//

import SwiftUI
import DataKit

/// One character per square with dashed center guides, like kanji practice paper.
struct PracticeCells: View {
    let text: String
    var cellSize: CGFloat = 36
    /// Off for fixed artwork such as the splash, where growing would overflow the screen.
    var scalesWithText = true

    @ScaledMetric(relativeTo: .title2) private var textScale: CGFloat = 1

    var body: some View {
        let side = scalesWithText ? cellSize * textScale : cellSize
        HStack(spacing: -1) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                PracticeSquare(character: String(character), side: side)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct PracticeSquare: View {
    let character: String
    let side: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(Forest.sunken)
            PracticeGuides()
                .stroke(Forest.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Rectangle().strokeBorder(Forest.line, lineWidth: 1)
            Text(character)
                .font(.custom(Font.headwordFace, fixedSize: side * 0.62))
                .foregroundStyle(Forest.ink)
        }
        .frame(width: side, height: side)
    }
}

private struct PracticeGuides: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Falls back to plain Mincho text when the word is too long for practice cells.
struct Headword: View {
    let text: String
    var cellSize: CGFloat = 34

    var body: some View {
        ViewThatFits(in: .horizontal) {
            PracticeCells(text: text, cellSize: cellSize)
            Text(text)
                .font(.headword(cellSize * 0.62))
                .foregroundStyle(Forest.ink)
                .lineLimit(2)
        }
    }
}

struct LevelTag: View {
    let level: String

    var body: some View {
        Text(level)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Forest.inkMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Forest.sunken, in: .rect(cornerRadius: 6))
            .accessibilityLabel("JLPT \(level)")
    }
}

struct StudyEntry: Identifiable, Hashable {
    let id: String
    let headword: String
    let reading: String?
    let meaning: String
    let level: String
}

extension Kotoba {
    var studyEntry: StudyEntry {
        let headword = kanji.isEmpty ? furigana : kanji
        return StudyEntry(
            id: id,
            headword: headword,
            reading: furigana == headword ? nil : furigana,
            meaning: english.joined(separator: ", "),
            level: jlptLevel.rawValue
        )
    }
}

extension Kanji {
    var studyEntry: StudyEntry {
        let readings = (onyomi + kunyomi).prefix(3).joined(separator: "  ")
        return StudyEntry(
            id: id,
            headword: kanji,
            reading: readings.isEmpty ? nil : readings,
            meaning: meanings.joined(separator: ", "),
            level: jlptLevel.rawValue
        )
    }
}

struct StudyRow: View {
    let entry: StudyEntry
    var showsLevel = true

    var body: some View {
        HStack(alignment: .top, spacing: Forest.Space.m) {
            VStack(alignment: .leading, spacing: Forest.Space.s) {
                Headword(text: entry.headword)
                if let reading = entry.reading {
                    Text(reading)
                        .font(.subheadline)
                        .foregroundStyle(Forest.inkMuted)
                }
                Text(entry.meaning)
                    .font(.body)
                    .foregroundStyle(Forest.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if showsLevel {
                LevelTag(level: entry.level)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Forest.inkMuted)
                .padding(.top, Forest.Space.s)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Forest.Space.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct StudyRemovalActions: ViewModifier {
    let entry: StudyEntry
    let noun: String
    let onDelete: (StudyEntry) -> Void
    @State private var isConfirming = false

    func body(content: Content) -> some View {
        content
            .swipeActions(allowsFullSwipe: false) {
                Button("Remove") { isConfirming = true }
                    .tint(Forest.danger)
            }
            .contextMenu {
                Button("Remove from collection", systemImage: "trash", role: .destructive) {
                    isConfirming = true
                }
            }
            .confirmationDialog(
                "Remove \(entry.headword) from your collection?",
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) { onDelete(entry) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(noun == "word" ? "This word will be removed from your collection and progress." : "This \(noun) will be removed from your collection and progress, then offered next on Today.")
            }
    }
}

extension View {
    func studyRemovalActions(entry: StudyEntry, noun: String, onDelete: @escaping (StudyEntry) -> Void) -> some View {
        modifier(StudyRemovalActions(entry: entry, noun: noun, onDelete: onDelete))
    }
}

/// Empty and error states: say why, then offer the one action that fixes it.
struct StateMessage: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Forest.Space.m) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Forest.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Forest.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(Forest.moss)
                    .padding(.top, Forest.Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Forest.Space.xxl)
        .padding(.horizontal, Forest.Space.xl)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Forest.onMoss)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Forest.moss.opacity(isEnabled ? 1 : 0.5), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ProgressTrack: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Forest.sunken)
                Capsule()
                    .fill(Forest.moss)
                    .frame(width: max(value > 0 ? 6 : 0, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

extension String {
    /// "kanji" has no English plural form.
    var pluralNoun: String { self == "kanji" ? self : self + "s" }
}

enum StudyKind: String, CaseIterable, Identifiable {
    case words = "Words"
    case kanji = "Kanji"
    case grammar = "Grammar"
    case sentences = "Sentences"
    case cards = "Your cards"

    var savedKind: SavedStudyKind {
        switch self { case .words: return .word; case .kanji: return .kanji; case .grammar: return .grammar; case .sentences: return .sentence; case .cards: return .customCard }
    }

    var id: Self { self }
}

struct StudyKindPicker: View {
    @Binding var selection: StudyKind

    var body: some View {
        Picker("Show", selection: $selection.animation(.easeInOut(duration: 0.2))) {
            ForEach(StudyKind.allCases) { kind in
                Text(kind.rawValue).tag(kind)
            }
        }
        .pickerStyle(.menu)
    }
}

struct ScreenHeader: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.xs) {
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Forest.inkMuted)
            }
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Forest.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
