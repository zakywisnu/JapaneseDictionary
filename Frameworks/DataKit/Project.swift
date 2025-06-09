import ProjectDescription
import ProjectDescriptionHelpers

func targets() -> [Target] {
    var target: [Target] = []
    target += Target.create(
        name: "DataKit",
        product: .framework,
        destination: [.iPhone],
        dependencies: [
            .project(target: "CoreKit", path: "../CoreKit", status: .required, condition: nil),
        ],
        resources: ["Resources/**"],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: false
    )
    return target
}

let project = Project(
    name: "DataKit",
    packages: [],
    targets: targets()
)
