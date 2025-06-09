//
//  AppsOnboardingComposer.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 16/05/25.
//

import Foundation
import DomainKit
import SwiftUI

public enum AppsOnboardingComposer {
    public static func make() -> some View {
        let viewModel = AppsOnboardingViewModel()
        return AppsOnboardingView(viewModel: viewModel)
    }
}
