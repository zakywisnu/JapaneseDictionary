//
//  Spotlight.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 08/06/25.
//

import SwiftUI
import ZeroDesignKit

public extension View {
    @ViewBuilder
    func addSpotlight(_ id: Int, shape: InstructionShape = .circle, roundedRadius: CGFloat = 0, text: String = "") -> some View {
        self
            .anchorPreference(key: SpotlightBoundsKey.self, value: .bounds) {
                [id: SpotlightBoundsKeyProperties(shape: shape, anchor: $0, text: text, radius: roundedRadius)]
            }
    }
    
    @ViewBuilder
    func addSpotlightOverlay(show: Binding<Bool>, currentSpot: Binding<Int>) -> some View {
        self
            .overlayPreferenceValue(SpotlightBoundsKey.self) { values in
                if show.wrappedValue {
                    GeometryReader { proxy in
                        if let preference = values.first(where: { item in
                            item.key == currentSpot.wrappedValue
                        }) {
                            let screenSize = proxy.size
                            let anchor = proxy[preference.value.anchor]
                            
                            SpotlightHelperView(
                                screenSize: screenSize,
                                rect: anchor,
                                show: show,
                                currentSpot: currentSpot,
                                properties: preference.value
                            ) {
                                if currentSpot.wrappedValue <= (values.count) {
                                    currentSpot.wrappedValue += 1
                                } else {
                                    show.wrappedValue = false
                                }
                            }
                        }
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: show.wrappedValue)
                    .animation(.easeInOut, value: currentSpot.wrappedValue)
                }
            }
    }
    
    @ViewBuilder
    func SpotlightHelperView(
        screenSize: CGSize,
        rect: CGRect,
        show: Binding<Bool>,
        currentSpot: Binding<Int>,
        properties: SpotlightBoundsKeyProperties,
        onTap: @escaping () -> Void
    ) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .opacity(show.wrappedValue ? 1 : 0)
            .overlay(alignment: .topLeading) {
                Text(properties.text)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .opacity(0)
                    .overlay {
                        GeometryReader { proxy in
                            let textSize = proxy.size
                            Text(properties.text)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(DefaultColors.primary)
                                .padding(8)
                                .background(Color.white.opacity(0.6))
                                .clipShape(.rect(cornerRadius: 8))
                                .offset(x: (rect.minX + textSize.width) > (screenSize.width - 16) ? -((rect.minX + textSize.width) - (screenSize.width - 16)) - 16 : 0)
                                .offset(y: (rect.maxY + textSize.height) > (screenSize.height - 50) ? -(textSize.height + (rect.maxY - rect.minY) + 16) : 16)
                                .frame(width: textSize.width + 16, height: textSize.height + 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .offset(x: rect.minX, y: rect.maxY)
                        .onTapGesture {
                            onTap()
                        }
                    }
            }
            .mask {
                Rectangle()
                    .overlay(alignment: .topLeading) {
                        let radius = properties.shape == .circle ? (rect.width / 2) : (properties.shape == .rectangle ? 0 : properties.radius)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .frame(width: rect.width + 8, height: rect.height + 8)
                            .offset(x: rect.minX - 4, y: rect.minY - 4)
                            .blendMode(.destinationOut)
                    }
            }
    }
}
