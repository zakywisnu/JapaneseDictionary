//
//  Projects.swift
//  Config
//
//  Created by Ahmad Zaky W on 09/05/25.
//

import ProjectDescription
import ProjectDescriptionHelpers

let infoPlist: [String: Plist.Value] = [
    "UIApplicationSceneManifest": [
        "UIApplicationSupportsMultipleScenes": true,
        "UISceneConfigurations": [
            "UIWindowSceneSessionRoleApplication": [
                [
                    "UISceneConfigurationName": "Default Configuration",
                    "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                ]
            ]
        ]
    ],
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
//            .project(target: "ToDoSwiftUI", path: "../Frameworks/ToDoSwiftUI/", status: .required, condition: nil),
//            .project(target: "CoreKit", path: "../Frameworks/CoreKit/", status: .required, condition: nil),
//            .project(target: "DomainKit", path: "../Frameworks/DomainKit/", status: .required, condition: nil),
        ],
        infoPlist: infoPlist,
        resources: ["Resources/**"],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: true
    )
    
//    target += Target.create(
//        name: "JapaneseDictionaryWidget",
//        product: .appExtension,
//        destination: .iOS,
//        dependencies: [],
//        infoPlist: ["NSExtension": ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]],
//        sources: ["JapaneseDictionaryWidget/**"],
//        deploymentTargets: .iOS("18.0"),
//        withUnitTest: false
//    )
    return target
}

let project = Project(
    name: "JapaneseDictionary",
    packages: [],
    targets: targets()
)
