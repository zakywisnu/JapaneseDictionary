import ProjectDescription

let nameAttributes: Template.Attribute = .required("name")

let appExampleContents = """
import Foundation

struct \(nameAttributes) { }
"""

let appTestContents = """
import Foundation
import XCTest

final class \(nameAttributes)Tests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func test_example() {
        // Add your test here
    }

}
"""

let appTemplate = Template(
    description: "App template",
    attributes: [
        nameAttributes,
        .optional("platform", default: "iOS"),
    ], items: [
        .string(path: "\(nameAttributes)/Sources/\(nameAttributes).swift", contents: appExampleContents),
        .string(path: "\(nameAttributes)/Tests/\(nameAttributes)Tests.swift", contents: appTestContents),
        .file(path: "\(nameAttributes)/Project.swift", templatePath: "app.stencil"),
    ]
)
