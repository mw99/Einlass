// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Einlass",
    dependencies: [ 
        .Package(url: "https://github.com/mw99/OhhAuth.git", majorVersion: 1),
    ]
)
