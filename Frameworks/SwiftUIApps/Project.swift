import ProjectDescription
import ProjectDescriptionHelpers

func targets() -> [Target] {
    var target: [Target] = []
    target += Target.create(
        name: "SwiftUIApps",
        product: .framework,
        destination: [.iPhone],
        dependencies: [
            .project(target: "DomainKit", path: "../DomainKit", status: .required, condition: nil),
        ],
        resources: ["Resources/**"],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: false
    )
    return target
}

let project = Project(
    name: "SwiftUIApps",
    packages: [],
    targets: targets()
)
