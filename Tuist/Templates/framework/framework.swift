import ProjectDescription
let nameAttribute: Template.Attribute = .required("name")

let exampleContents = """
import Foundation

struct \(nameAttribute) { }
"""

let testContents = """
import Foundation
import XCTest

final class \(nameAttribute)Tests: XCTestCase {

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

let template = Template(
    description: "Framework template",
    attributes: [
        nameAttribute,
        .optional("platform", default: "iOS"),
    ], items: [
        .string(path: "Frameworks/\(nameAttribute)/Sources/\(nameAttribute).swift", contents: exampleContents),
        .string(path: "Frameworks/\(nameAttribute)/Tests/\(nameAttribute)Tests.swift", contents: testContents),
        .file(path: "Frameworks/\(nameAttribute)/Project.swift", templatePath: "framework.stencil"),
    ]
)