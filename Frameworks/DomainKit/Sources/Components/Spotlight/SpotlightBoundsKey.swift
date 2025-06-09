//
//  BoundsKey.swift
//  DomainKit
//
//  Created by Ahmad Zaky W on 08/06/25.
//

import SwiftUI

public struct SpotlightBoundsKey: PreferenceKey {
    public static var defaultValue: [Int: SpotlightBoundsKeyProperties] = [:]
    
    public static func reduce(value: inout [Int : SpotlightBoundsKeyProperties], nextValue: () -> [Int : SpotlightBoundsKeyProperties]) {
        value.merge(nextValue()) { $1 }
    }
    
}

public struct SpotlightBoundsKeyProperties {
    public var shape: InstructionShape
    public var anchor: Anchor<CGRect>
    public var text: String = ""
    public var radius: CGFloat = 0
    
    public init(
        shape: InstructionShape,
        anchor: Anchor<CGRect>,
        text: String = "",
        radius: CGFloat = 0
    ) {
        self.shape = shape
        self.anchor = anchor
        self.text = text
        self.radius = radius
    }
}
