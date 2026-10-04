// swift-tools-version: 6.3

import PackageDescription

let package = Package(
	name: "swift-sharing-keychain",
	platforms: [
		.iOS(.v18),
		.macOS(.v15),
		.tvOS(.v18),
		.watchOS(.v11),
	],
	products: [
		.library(
			name: "SharingKeychain",
			targets: ["SharingKeychain"]
		),
	],
	dependencies: [
		.package(
			url: "https://github.com/pointfreeco/swift-sharing",
			from: "2.10.1"
		),
	],
	targets: [
		.target(
			name: "SharingKeychain",
			dependencies: [
				.product(
					name: "Sharing",
					package: "swift-sharing"
				),
			]
		),
		.testTarget(
			name: "SharingKeychainTests",
			dependencies: [
				"SharingKeychain",
			]
		),
	]
)

for target in package.targets {
	target.swiftSettings = (target.swiftSettings ?? []) + [
		.enableUpcomingFeature("InternalImportsByDefault"),
		.enableUpcomingFeature("MemberImportVisibility"),
	]
}
