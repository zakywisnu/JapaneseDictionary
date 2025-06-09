

import SwiftUI

/// Semantic color tokens for consistent UI elements
public enum TokenColors {
    public enum Text {
        public static let primary = SystemColors.label
        public static let secondary = SystemColors.secondaryLabel
        public static let tertiary = SystemColors.tertiaryLabel
        public static let placeholder = SystemColors.placeholderText
        public static let inverse = SystemColors.background
    }
    
    public enum Action {
        public static let primary = Palette.azure
        public static let secondary = Palette.mint
        public static let warning = Palette.coral
        public static let success = Palette.mint
        public static let accent = Palette.lavender
        public static let highlight = Palette.sunshine
    }
    
    public enum Surface {
        public static let primary = SystemColors.background
        public static let secondary = SystemColors.secondaryBackground
        public static let tertiary = SystemColors.tertiaryBackground
        public static let grouped = SystemColors.groupedBackground
        
        public static let card = SystemColors.secondaryBackground
        public static let overlay = Color.black.opacity(0.4)
    }
    
    public enum Border {
        public static let primary = SystemColors.separator
        public static let prominent = SystemColors.opaqueSeparator
        public static let subtle = SystemColors.fill
    }
}

