//
//  Projects.swift
//  Config
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import ProjectDescription
import ProjectDescriptionHelpers

let infoPlist: [String: Plist.Value] = [
    "UILaunchStoryboardName": "LaunchScreen",
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "NSSupportsLiveActivities": true
]

func targets() -> [Target] {
    var target: [Target] = []
    target += Target.create(
        name: "JapaneseDictionary",
        product: .app,
        destination: [.iPhone],
        dependencies: [
            .project(target: "SwiftUIApps", path: "../Frameworks/SwiftUIApps/", status: .required, condition: nil),
            .project(target: "CoreKit", path: "../Frameworks/CoreKit/", status: .required, condition: nil),
            .project(target: "DomainKit", path: "../Frameworks/DomainKit/", status: .required, condition: nil),
            .project(target: "DataKit", path: "../Frameworks/DataKit/", status: .required, condition: nil),
            .external(name: "ZeroNetwork", condition: nil),
            .external(name: "ZeroCoreKit", condition: nil),
            .external(name: "ZeroDesignKit", condition: nil),
            .target(name: "JapaneseDictionaryWidget")
        ],
        infoPlist: infoPlist,
        resources: ["Resources/**"],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: true
    )
    
    target += Target.create(
        name: "JapaneseDictionaryWidget",
        product: .appExtension,
        destination: .iOS,
        dependencies: [
            .project(target: "SwiftUIApps", path: "../Frameworks/SwiftUIApps/", status: .required, condition: nil),
            .project(target: "DomainKit", path: "../Frameworks/DomainKit/", status: .required, condition: nil),
            .project(target: "DataKit", path: "../Frameworks/DataKit/", status: .required, condition: nil),
            .external(name: "ZeroDesignKit", condition: nil),
        ],
        infoPlist: ["NSExtension": ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]],
        sources: ["JapaneseDictionaryWidget/**"],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: false
    )
    return target
}

let project = Project(
    name: "JapaneseDictionary",
    packages: [],
    targets: targets()
)
