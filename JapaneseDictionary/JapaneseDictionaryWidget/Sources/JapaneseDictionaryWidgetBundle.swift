//
//  AppWidgetBundle.swift
//  JapaneseDictionary
//
//  Created by Ahmad Zaky W on 04/06/25.
//

import WidgetKit
import SwiftUI

@main
struct JapaneseDictionaryWidgetBundle: WidgetBundle {
    var body: some Widget {
        JapaneseDictionaryWidget()
        JapaneseDictionaryWidgetControl()
    }
}

