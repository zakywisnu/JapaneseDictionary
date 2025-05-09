// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        // Customize the product types for specific package product
        // Default is .staticFramework
        // productTypes: ["Alamofire": .framework,]
        productTypes: [
            "ZeroNetwork": .framework,
            "ZeroCoreKit": .framework,
            "ZeroDesignKit": .framework
        ]
    )
#endif

let package = Package(
    name: "JapaneseDictionary",
    dependencies: [
        // Add your own dependencies here:
        // .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0"),
        // You can read more about dependencies here: https://docs.tuist.io/documentation/tuist/dependencies
        .package(url: "https://github.com/zakywisnu/ZeroNetwork.git", branch: "main"),
        .package(url: "https://github.com/zakywisnu/ZeroCoreKit.git", branch: "main"),
        .package(url: "https://github.com/zakywisnu/ZeroDesignKit.git", branch: "main"),
    ]
)
