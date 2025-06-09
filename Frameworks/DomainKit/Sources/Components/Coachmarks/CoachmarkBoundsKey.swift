//
//  Coachmark.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 08/06/25.
//

import SwiftUI

public struct CoachmarkStep {
    public var id: Int
    public var model: CoachmarkModel
    
    public init(id: Int, model: CoachmarkModel) {
        self.id = id
        self.model = model
    }
}

public struct CoachmarkBoundsKey: PreferenceKey {
    public static var defaultValue: [Int: CoachmarkBoundsKeyProperties] = [:]
    
    public static func reduce(value: inout [Int : CoachmarkBoundsKeyProperties], nextValue: () -> [Int : CoachmarkBoundsKeyProperties]) {
        value.merge(nextValue()) { $1 }
    }
    
}

public struct CoachmarkBoundsKeyProperties {
    public var shape: InstructionShape
    public var anchor: Anchor<CGRect>
    public var title: CoachmarkTextConfig
    public var description: CoachmarkTextConfig
    public var tooltipPosition: TooltipPosition
    public var tooltipAlignment: TooltipAlignment
    public var radius: CGFloat
    public var offset: CGSize
    
    public init(
        shape: InstructionShape,
        anchor: Anchor<CGRect>,
        title: CoachmarkTextConfig,
        description: CoachmarkTextConfig,
        tooltipPosition: TooltipPosition = .auto,
        tooltipAlignment: TooltipAlignment = .auto,
        radius: CGFloat = 0,
        offset: CGSize = .zero
    ) {
        self.shape = shape
        self.anchor = anchor
        self.title = title
        self.radius = radius
        self.description = description
        self.offset = offset
        self.tooltipPosition = tooltipPosition
        self.tooltipAlignment = tooltipAlignment
    }
}

public struct CoachmarkTextConfig {
    public var text: String
    public var font: Font
    public var fontWeight: Font.Weight
    public var foreground: Color
    
    public init(text: String, font: Font, fontWeight: Font.Weight, foreground: Color) {
        self.text = text
        self.font = font
        self.fontWeight = fontWeight
        self.foreground = foreground
    }
}

public struct CoachmarkModel {
    public var shape: InstructionShape
    public var title: CoachmarkTextConfig
    public var description: CoachmarkTextConfig
    public var tooltipPosition: TooltipPosition
    public var tooltipAlignment: TooltipAlignment
    public var radius: CGFloat
    public var offset: CGSize
    
    public init(
        shape: InstructionShape = .circle,
        title: CoachmarkTextConfig,
        description: CoachmarkTextConfig,
        tooltipPosition: TooltipPosition = .auto,
        tooltipAlignment: TooltipAlignment = .auto,
        radius: CGFloat = 0,
        offset: CGSize = .zero
    ) {
        self.shape = shape
        self.title = title
        self.description = description
        self.tooltipPosition = tooltipPosition
        self.tooltipAlignment = tooltipAlignment
        self.radius = radius
        self.offset = offset
    }
}

public enum CoachmarkAnimationType {
    case fadeInOut
    case slideInOut
}

public struct CoachmarkAnimationConfig {
    public var overlayAnimation: CoachmarkAnimationType
    public var tooltipAnimation: CoachmarkAnimationType
    public var duration: Double
    
    public init(
        overlayAnimation: CoachmarkAnimationType = .slideInOut,
        tooltipAnimation: CoachmarkAnimationType = .slideInOut,
        duration: Double = 0.3
    ) {
        self.overlayAnimation = overlayAnimation
        self.tooltipAnimation = tooltipAnimation
        self.duration = duration
    }
    
    public static let `default` = CoachmarkAnimationConfig()
}

public enum TooltipPosition {
    case top
    case bottom
    case auto
}

public enum TooltipAlignment {
    case leading
    case center
    case trailing
    case auto
}
