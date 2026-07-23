# SharingKeychain

A Keychain persistence strategy for [swift-sharing](https://github.com/pointfreeco/swift-sharing). Store and retrieve `Codable` values from the iOS/macOS Keychain using the `@Shared` property wrapper.

## Usage

```swift
import SharingKeychain

// String value with a default
@Shared(.keychain("authToken")) var authToken = ""

// Optional value
@Shared(.keychain("session")) var session: Session?

// Custom configuration
@Shared(.keychain("secret", accessibility: .whenUnlockedThisDeviceOnly)) var secret = ""

// iCloud Keychain sync (only on .afterFirstUnlock / .whenUnlocked)
@Shared(.keychain("syncedToken", accessibility: .afterFirstUnlock(synchronizable: true))) var syncedToken = ""
```

### Type-safe keys

Define reusable keys with defaults:

```swift
extension SharedKey where Self == KeychainKey<String>.Default {
  static var authToken: Self {
    Self[.keychain("authToken"), default: ""]
  }
}

@Shared(.authToken) var authToken
```

### Configuration options

| Parameter | Type | Default | Description |
|---|---|---|---|
| `key` | `String` | required | Keychain account identifier |
| `service` | `String?` | Bundle ID | Keychain service namespace |
| `accessGroup` | `String?` | `nil` | For sharing items between apps |
| `accessibility` | `KeychainItemAccessibility` | `.afterFirstUnlock` | When the item can be accessed, and whether it syncs via iCloud (see below) |

### Accessibility levels

| Level | When accessible | Migrates via backup |
|---|---|---|
| `.afterFirstUnlock` | After first unlock post-restart | Yes |
| `.afterFirstUnlockThisDeviceOnly` | After first unlock post-restart | No |
| `.whenUnlocked` | While device is unlocked | Yes |
| `.whenUnlockedThisDeviceOnly` | While device is unlocked | No |
| `.whenPasscodeSetThisDeviceOnly` | While unlocked, passcode required | No |

iCloud Keychain sync is opt-in and available **only** on `.afterFirstUnlock` and `.whenUnlocked`,
via their synchronizable form — `.afterFirstUnlock(synchronizable: true)` or
`.whenUnlocked(synchronizable: true)`. Apple rejects synchronising the three `ThisDeviceOnly`
levels, so they have no synchronizable variant and the invalid combination cannot be expressed.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/brzzdev/swift-sharing-keychain", from: "1.0.0"),
]
```

Then add `SharingKeychain` to your target's dependencies:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "SharingKeychain", package: "swift-sharing-keychain"),
  ]
)
```

## Requirements

- Swift 6.3+
- iOS 18+ / macOS 15+ / tvOS 18+ / watchOS 11+

## Testing

The `KeychainClient` dependency is automatically replaced with an in-memory implementation in tests via [swift-dependencies](https://github.com/pointfreeco/swift-dependencies):

```swift
import Dependencies
import SharingKeychain

@Test
func example() {
  withDependencies {
    $0.keychainClient = .testValue
  } operation: {
    @Shared(.keychain("token")) var token = ""
    $token.withLock { $0 = "secret" }
    #expect(token == "secret")
  }
}
```

## License

MIT
