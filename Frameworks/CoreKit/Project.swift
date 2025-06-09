import ProjectDescription
import ProjectDescriptionHelpers

func targets() -> [Target] {
    var target: [Target] = []
    target += Target.create(
        name: "CoreKit",
        product: .framework,
        destination: [.iPhone],
        dependencies: [
            .external(name: "ZeroNetwork", condition: nil),
            .external(name: "ZeroCoreKit", condition: nil)
        ],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: false
    )
    return target
}

let project = Project(
    name: "CoreKit",
    packages: [],
    targets: targets()
)
