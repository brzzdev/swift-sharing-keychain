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
		// Declared explicitly even though Sharing already pulls it in: KeychainClient
		// and KeychainKey both `import Dependencies` directly. SwiftPM tolerates the
		// undeclared transitive import because it links the whole resolved graph, but
		// generators that emit one target per product — Tuist, Bazel — link only what
		// is declared, and SharingKeychain then fails to find the Dependencies symbols.
		.package(
			url: "https://github.com/pointfreeco/swift-dependencies",
			from: "1.5.1"
		),
		.package(
			url: "https://github.com/pointfreeco/swift-sharing",
			from: "2.9.1"
		),
	],
	targets: [
		.target(
			name: "SharingKeychain",
			dependencies: [
				.product(
					name: "Dependencies",
					package: "swift-dependencies"
				),
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
