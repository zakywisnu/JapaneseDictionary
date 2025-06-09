import ProjectDescription
import ProjectDescriptionHelpers

func targets() -> [Target] {
    var target: [Target] = []
    target += Target.create(
        name: "DomainKit",
        product: .framework,
        destination: [.iPhone],
        dependencies: [
            .project(target: "DataKit", path: "../DataKit", status: .required, condition: nil),
        ],
        deploymentTargets: .iOS("18.0"),
        withUnitTest: false
    )
    return target
}

let project = Project(
    name: "DomainKit",
    packages: [],
    targets: targets()
)
