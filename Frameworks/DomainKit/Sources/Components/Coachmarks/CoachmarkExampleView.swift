//
//  CoachmarkExampleView.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 09/06/25.
//

import SwiftUI
import ZeroDesignKit

struct CoachmarkExampleView: View {
    @State var showCoachmark: Bool = true
    @State var currentSpot: Int = 0
    @State var steps: [CoachmarkStep] = Self.setCoachmarkSteps()
    
    var body: some View {
        HeaderView(config: .init(title: "ExampleView")) {
            HStack(spacing: 16) {
                Button {
                    
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
                .addCoachmark(steps[0].id, with: steps[0].model)
            }
        } content: {
                VStack {
                    Spacer()
                    Button("Ini button") {
                        
                    }
                    .buttonStyle(.borderedProminent)
                    .addCoachmark(steps[1].id, with: steps[1].model)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .background(DefaultColors.background.opacity(0.4))
        .addCoachmarkOverlay(show: $showCoachmark, currentSpot: $currentSpot) {
            
        }
    }
    
    static func setCoachmarkSteps() -> [CoachmarkStep] {
        return [
            CoachmarkStep(
                id: 0,
                model: .init(
                    shape: .rounded,
                    title: .init(
                        text: "Refresh Button asdjoaisdjoiasjdoiasjdoiasjdoiasjdioasjdioasjdioasjioaisjdoiasjdo",
                        font: .caption,
                        fontWeight: .bold,
                        foreground: .black
                    ),
                    description: .init(
                        text: "Tap this button to refresh the content",
                        font: .caption2,
                        fontWeight: .semibold,
                        foreground: .black
                    ),
                    tooltipPosition: .auto,
                    tooltipAlignment: .auto,
                    radius: 4,
                    offset: CGSize(width: 0, height: 0)
                )
            ),
            CoachmarkStep(
                id: 1,
                model: .init(
                    shape: .rounded,
                    title: .init(
                        text: "Main Action",
                        font: .caption,
                        fontWeight: .bold,
                        foreground: .black
                    ),
                    description: .init(
                        text: "This is the primary action button for the screen",
                        font: .caption2,
                        fontWeight: .semibold,
                        foreground: .black
                    ),
                    tooltipPosition: .auto,
                    tooltipAlignment: .auto,
                    radius: 4,
                    offset: CGSize(width: 0, height: 0)
                )
            )
        ]
    }
}

#Preview {
    CoachmarkExampleView()
}
