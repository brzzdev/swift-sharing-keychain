import Dependencies
import Foundation
public import Sharing

/// A unique identifier for a Keychain-backed shared key.
public struct KeychainKeyID: Hashable, Sendable {
  static let defaultService = "com.sharing.keychain"

  let accessGroup: String?
  let key: String
  let service: String
  let synchronizable: Bool
}

private func _isOptionalNil(_ value: any Sendable) -> Bool {
  guard let optional = value as? _OptionalProtocol else { return false }
  return optional._isNil
}

private protocol _OptionalProtocol {
  var _isNil: Bool { get }
}

extension Optional: _OptionalProtocol {
  var _isNil: Bool { self == nil }
}

private enum JSON {
  static let decoder = JSONDecoder()
  static let encoder = JSONEncoder()
}

/// A persistence strategy that stores `Codable & Sendable` values in the Keychain.
public struct KeychainKey<Value: Codable & Sendable>: SharedKey {
  private let accessibility: KeychainItemAccessibility
  private let client: KeychainClient
  private let keyID: KeychainKeyID

  public var id: KeychainKeyID { keyID }

  init(
    key: String,
    service: String?,
    accessGroup: String?,
    accessibility: KeychainItemAccessibility
  ) {
    @Dependency(\.keychainClient) var keychainClient
    self.accessibility = accessibility
    self.client = keychainClient
    self.keyID = KeychainKeyID(
      accessGroup: accessGroup,
      key: key,
      service: service ?? Bundle.main.bundleIdentifier ?? KeychainKeyID.defaultService,
      synchronizable: accessibility.synchronizable
    )
  }

  public func load(
    context: LoadContext<Value>,
    continuation: LoadContinuation<Value>
  ) {
    let query = buildQuery()
    do {
      guard let data = try client.getData(query) else {
        continuation.resumeReturningInitialValue()
        return
      }
      let value = try JSON.decoder.decode(Value.self, from: data)
      continuation.resume(returning: value)
    } catch let error as KeychainError {
      continuation.resume(throwing: error)
    } catch {
      continuation.resume(throwing: KeychainError.decodingFailed(String(describing: error)))
    }
  }

  public func save(
    _ value: Value,
    context: SaveContext,
    continuation: SaveContinuation
  ) {
    do {
      if _isOptionalNil(value) {
        try client.delete(buildQuery())
      } else {
        let data = try JSON.encoder.encode(value)
        try client.setData(data, buildQuery(), accessibility)
      }
      continuation.resume()
    } catch let error as KeychainError {
      continuation.resume(throwing: error)
    } catch {
      continuation.resume(throwing: KeychainError.encodingFailed(String(describing: error)))
    }
  }

  public func subscribe(
    context: LoadContext<Value>,
    subscriber: SharedSubscriber<Value>
  ) -> SharedSubscription {
    // The keychain has no OS-level change notification API (unlike UserDefaults
    // KVO or file system DispatchSource), so there are no external changes to
    // observe. @Shared already handles in-process synchronisation.
    SharedSubscription {}
  }

  private func buildQuery() -> [String: Any] {
    var query: [String: Any] = [
      kSecAttrAccount as String: keyID.key,
      kSecAttrService as String: keyID.service,
      kSecClass as String: kSecClassGenericPassword,
    ]
    if let accessGroup = keyID.accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }
    if keyID.synchronizable {
      query[kSecAttrSynchronizable as String] = kCFBooleanTrue!
    }
    #if os(macOS)
      query[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue!
    #endif
    return query
  }
}

extension KeychainKey: CustomStringConvertible {
  public var description: String {
    ".keychain(\(String(reflecting: keyID.key)))"
  }
}

extension SharedReaderKey {
  /// Creates a Keychain-backed shared key.
  ///
  /// - Parameters:
  ///   - key: The Keychain account identifier.
  ///   - accessGroup: An optional access group for sharing between apps.
  ///   - accessibility: Controls when the item can be accessed, and whether it syncs via iCloud
  ///     Keychain. Defaults to ``KeychainItemAccessibility/afterFirstUnlock``. Sync is available
  ///     only on the ``KeychainItemAccessibility/afterFirstUnlock`` and
  ///     ``KeychainItemAccessibility/whenUnlocked`` levels, via their `(synchronizable:)` form.
  ///     Changing whether a key synchronises creates a separate Keychain item rather than
  ///     modifying the original.
  ///   - service: The Keychain service namespace. Defaults to the bundle identifier, or
  ///     `"com.sharing.keychain"` when the bundle identifier is unavailable (e.g. CLI tools, test
  ///     hosts). Pass an explicit value to avoid collisions in those environments.
  public static func keychain<Value: Codable & Sendable>(
    _ key: String,
    accessGroup: String? = nil,
    accessibility: KeychainItemAccessibility = .afterFirstUnlock,
    service: String? = nil
  ) -> Self where Self == KeychainKey<Value> {
    KeychainKey(
      key: key,
      service: service,
      accessGroup: accessGroup,
      accessibility: accessibility
    )
  }
}
