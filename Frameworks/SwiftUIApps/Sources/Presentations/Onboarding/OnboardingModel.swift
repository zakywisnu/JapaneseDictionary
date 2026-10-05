//
//  OnboardingModel.swift
//  SwiftUIApps
//

import Foundation

public final class AppsOnboardingViewModel {
    struct Page: Identifiable {
        let id = UUID()
        let character: String
        let title: String
        let message: String
    }
    
    let pages: [Page] = [
        Page(
            character: "言",
            title: "One word at a time",
            message: "Add the next JLPT word or kanji whenever you're ready. The list starts at N5 and moves up as you go."
        ),
        Page(
            character: "漢",
            title: "Kanji with their readings",
            message: "Each kanji shows its on'yomi, kun'yomi, stroke count, and meanings. Words show their reading and English."
        ),
        Page(
            character: "森",
            title: "Everything stays on this iPhone",
            message: "No account and no sign-in. Your collection and progress are saved on this device and work offline."
        )
    ]
    
    public init() {}
}
