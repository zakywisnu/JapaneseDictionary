//
//  CoachmarkView.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 08/06/25.
//

import SwiftUI
import ZeroDesignKit

public extension View {
    @ViewBuilder
    func addCoachmark(_ id: Int, with properties: CoachmarkModel) -> some View {
        self
            .anchorPreference(key: CoachmarkBoundsKey.self, value: .bounds) {
                [id: CoachmarkBoundsKeyProperties(
                    shape: properties.shape,
                    anchor: $0,
                    title: properties.title,
                    description: properties.description,
                    tooltipPosition: properties.tooltipPosition,
                    tooltipAlignment: properties.tooltipAlignment,
                    radius: properties.radius,
                    offset: properties.offset
                )]
            }
    }
    
    @ViewBuilder
    func addCoachmarkOverlay(show: Binding<Bool>, currentSpot: Binding<Int>, _ onFinish: @escaping () -> Void) -> some View {
        self
            .overlayPreferenceValue(CoachmarkBoundsKey.self) { values in
                if show.wrappedValue {
                    GeometryReader { proxy in
                        if let preference = values.first(where: { item in
                            item.key == currentSpot.wrappedValue
                        }) {
                            let screenSize = proxy.size
                            let anchor = proxy[preference.value.anchor]
                            
                            CoachmarView(
                                screenSize: screenSize,
                                rect: anchor,
                                show: show,
                                currentSpot: currentSpot,
                                properties: preference.value) {
                                    if currentSpot.wrappedValue < (values.count - 1) {
                                        currentSpot.wrappedValue += 1
                                    } else {
                                        show.wrappedValue = false
                                        onFinish()
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
    func CoachmarView(
        screenSize: CGSize,
        rect: CGRect,
        show: Binding<Bool>,
        currentSpot: Binding<Int>,
        properties: CoachmarkBoundsKeyProperties,
        onTap: @escaping () -> Void
    ) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .opacity(show.wrappedValue ? 1 : 0)
            .overlay(alignment: .topLeading) {
                TooltipView(properties, show: show, currentSpot: currentSpot)
                .opacity(0)
                .overlay {
                    GeometryReader { proxy in
                        let textSize = proxy.size
                        
                        let calculatedPosition = calculateTooltipPosition(
                            rect: rect,
                            textSize: textSize,
                            screenSize: screenSize,
                            preferredPosition: properties.tooltipPosition
                        )
                        
                        let calculatedAlignment = calculateTooltipAlignment(
                            rect: rect,
                            textSize: textSize,
                            screenSize: screenSize,
                            preferredAlignment: properties.tooltipAlignment
                        )
                        TooltipView(properties, show: show, currentSpot: currentSpot)
                        .padding(12)
                        .background(Color.white.opacity(0.95))
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .frame(width: min(textSize.width + 24, screenSize.width - 32), height: textSize.height)
                        .position(
                            x: calculateTooltipX(
                                rect: rect,
                                textSize: textSize,
                                screenSize: screenSize,
                                alignment: calculatedAlignment
                            ),
                            y: calculateTooltipY(
                                rect: rect,
                                textSize: textSize,
                                screenSize: screenSize,
                                position: calculatedPosition
                            )
                        )
                        .onTapGesture {
                            onTap()
                        }
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
    
    @ViewBuilder
    func TooltipView(_ properties: CoachmarkBoundsKeyProperties, show: Binding<Bool>, currentSpot: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(properties.title.text)
                .font(properties.title.font)
                .fontWeight(properties.title.fontWeight)
                .foregroundStyle(properties.title.foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(properties.description.text)
                .font(properties.description.font)
                .fontWeight(properties.description.fontWeight)
                .foregroundStyle(properties.description.foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // TODO: to be developed
//            HStack(spacing: 16) {
//                Spacer()
//                Button {
//                    currentSpot.wrappedValue -= 1
//                } label: {
//                    Image(systemName: "arrow.left")
//                        .resizable()
//                        .renderingMode(.original)
//                        .frame(width: 16, height: 16)
//                        .foregroundStyle(.white)
//                        .padding(8)
//                        .background(DefaultColors.primary)
//                        .clipShape(.circle)
//                }
//
//                Button {
//                    currentSpot.wrappedValue += 1
//                } label: {
//                    Image(systemName: "arrow.right")
//                        .resizable()
//                        .renderingMode(.original)
//                        .frame(width: 16, height: 16)
//                        .foregroundStyle(.white)
//                        .padding(8)
//                        .background(DefaultColors.primary)
//                        .clipShape(.circle)
//                }
//            }
        }
    }
    
    private func calculateTooltipPosition(
        rect: CGRect,
        textSize: CGSize,
        screenSize: CGSize,
        preferredPosition: TooltipPosition
    ) -> TooltipPosition {
        guard preferredPosition == .auto else { return preferredPosition }
        
        let spaceAbove = rect.minY
        let spaceBelow = screenSize.height - rect.maxY
        let requiredSpace = textSize.height + 24
        
        if spaceBelow >= requiredSpace {
            return .bottom
        } else if spaceAbove >= requiredSpace {
            return .top
        } else {
            return spaceBelow > spaceAbove ? .bottom : .top
        }
    }
    
    private func calculateTooltipAlignment(
        rect: CGRect,
        textSize: CGSize,
        screenSize: CGSize,
        preferredAlignment: TooltipAlignment
    ) -> TooltipAlignment {
        guard preferredAlignment == .auto else { return preferredAlignment }
        
        let elementCenter = rect.midX
        let tooltipHalfWidth = textSize.width / 2
        let margin: CGFloat = 16
        
        if elementCenter - tooltipHalfWidth >= margin &&
           elementCenter + tooltipHalfWidth <= screenSize.width - margin {
            return .center
        }
        
        if rect.minX + textSize.width <= screenSize.width - margin {
            return .leading
        }
        
        if rect.maxX - textSize.width >= margin {
            return .trailing
        }
        
        return .center
    }
    
    private func calculateTooltipX(
        rect: CGRect,
        textSize: CGSize,
        screenSize: CGSize,
        alignment: TooltipAlignment
    ) -> CGFloat {
        let margin: CGFloat = 16
        let tooltipHalfWidth = textSize.width / 2
        
        switch alignment {
        case .leading:
            return max(tooltipHalfWidth + margin, rect.minX + tooltipHalfWidth)
        case .trailing:
            return min(screenSize.width - tooltipHalfWidth - margin, rect.maxX - tooltipHalfWidth)
        case .center, .auto:
            let idealX = rect.midX
            return max(tooltipHalfWidth + margin,
                      min(screenSize.width - tooltipHalfWidth - margin, idealX))
        }
    }
    
    private func calculateTooltipY(
        rect: CGRect,
        textSize: CGSize,
        screenSize: CGSize,
        position: TooltipPosition
    ) -> CGFloat {
        let margin: CGFloat = 32
        let tooltipHalfHeight = textSize.height / 2
        
        switch position {
        case .top:
            return max(tooltipHalfHeight + margin, rect.minY - tooltipHalfHeight - margin)
        case .bottom, .auto:
            return min(screenSize.height - tooltipHalfHeight - margin,
                      rect.maxY + tooltipHalfHeight + margin)
        }
    }
}

#Preview {
    CoachmarkExampleView()
}
