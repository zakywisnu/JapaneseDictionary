//
//  JapaneseDictionaryWidget.swift
//  JapaneseDictionaryWidget
//
//  Created by Ahmad Zaky W on 04/06/25.
//

import SwiftUIApps
import DomainKit
import WidgetKit
import SwiftUI
import ZeroDesignKit

struct Provider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), wordsProgress: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let progress = AppComposer.getProgressFromUserDefaults()
        print("success fetch snapshot: \(String(describing: progress))")
        return SimpleEntry(date: Date(), wordsProgress: progress)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        
        let nextUpdate = Calendar.current.date(
            byAdding: DateComponents(minute: 15),
            to: Date()
        )!
        
        let progress = AppComposer.getProgressFromUserDefaults()
        print("success fetch timeline: \(String(describing: progress))")
        entries.append(.init(date: Date(), wordsProgress: progress))

        return Timeline(entries: entries, policy: .after(nextUpdate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let wordsProgress: WordsProgress?
}

struct JapaneseDictionaryWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let totalProgress = (entry.wordsProgress?.kotobaProgress ?? 0) + (entry.wordsProgress?.kanjiProgress ?? 0)
            
            Text("Today's Progress")
                .font(.system(size: 10, weight: .bold))
            
            Text("\(totalProgress)")
                .font(.system(size: 64, weight: .bold))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical)
    }
}

struct JapaneseDictionaryWidget: Widget {
    let kind: String = "JapaneseDictionaryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            JapaneseDictionaryWidgetEntryView(entry: entry)
                .containerBackground(DefaultColors.background.opacity(0.4), for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    JapaneseDictionaryWidget()
} timeline: {
    SimpleEntry(date: .now, wordsProgress: nil)
    SimpleEntry(date: .now, wordsProgress: nil)
}
