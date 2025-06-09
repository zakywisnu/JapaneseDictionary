

import SwiftUI
import DomainKit
import ZeroDesignKit

public class AppsOnboardingViewModel {
    var pages: [OnboardingPage] = [
        OnboardingPage(
            image: .init(
                image: Image(systemName: "book.fill"),
                color: DefaultColors.Badge.background
            ),
            title: .init(
                text: "Master Japanese Faster",
                font: .title,
                weight: .bold,
                color: DefaultColors.primary
            ),
            description: .init(
                text: "Learn thousands of words with clear definitions, examples, and audio — all in one place.",
                font: .body,
                weight: .regular,
                color: DefaultColors.secondary
            )
        ),
        
        OnboardingPage(
            image: .init(
                image: Image(systemName: "magnifyingglass.circle.fill"),
                color: DefaultColors.Badge.background
            ),
            title: .init(
                text: "Visual Kanji Lookup",
                font: .title,
                weight: .bold,
                color: DefaultColors.primary
            ),
            description: .init(
                text: "Use stroke input, camera, or radicals to explore kanji like never before.",
                font: .body,
                weight: .regular,
                color: DefaultColors.secondary
            )
        ),
        
        OnboardingPage(
            image: .init(
                image: Image(systemName: "icloud.slash.fill"),
                color: DefaultColors.Badge.background
            ),
            title: .init(
                text: "Access Offline Anytime",
                font: .title,
                weight: .bold,
                color: DefaultColors.primary
            ),
            description: .init(
                text: "No Wi-Fi? No problem. Use the dictionary anywhere, anytime — even offline.",
                font: .body,
                weight: .regular,
                color: DefaultColors.secondary
            )
        )
    ]
}
