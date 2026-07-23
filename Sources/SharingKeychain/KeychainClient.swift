public import Dependencies
public import Foundation
import Security
import Synchronization

extension DependencyValues {
	public var keychainClient: KeychainClient {
		get { self[KeychainClient.self] }
		set { self[KeychainClient.self] = newValue }
	}
}

public struct KeychainClient: Sendable {
  public var delete: @Sendable (_ query: [String: Any]) throws(KeychainError) -> Void
  public var getData: @Sendable (_ query: [String: Any]) throws(KeychainError) -> Data?

  /// Uses update-or-add semantics.
  public var setData:
    @Sendable (
      _ data: Data, _ query: [String: Any], _ accessibility: KeychainItemAccessibility
    ) throws(KeychainError) -> Void
}

extension KeychainClient: DependencyKey {
  public static let liveValue = KeychainClient(
    delete: { (query: [String: Any]) throws(KeychainError) in
      let status = SecItemDelete(query as CFDictionary)
      if status != errSecItemNotFound, let error = KeychainError.from(status: status) {
        throw error
      }
    },
    getData: { (query: [String: Any]) throws(KeychainError) -> Data? in
      var query = query
      query[kSecReturnData as String] = kCFBooleanTrue
      query[kSecMatchLimit as String] = kSecMatchLimitOne

      var result: AnyObject?
      let status = SecItemCopyMatching(query as CFDictionary, &result)

      if status == errSecItemNotFound {
        return nil
      }
      if let error = KeychainError.from(status: status) {
        throw error
      }
      return result as? Data
    },
    setData: {
      (data: Data, query: [String: Any], accessibility: KeychainItemAccessibility)
        throws(KeychainError) in
      let updateAttributes: [String: Any] = [
        kSecAttrAccessible as String: accessibility.cfValue,
        kSecValueData as String: data,
      ]

      let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

      if status == errSecItemNotFound {
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility.cfValue

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
          // Another thread/process added the item between our update and add attempts.
          let retryStatus = SecItemUpdate(
            query as CFDictionary, updateAttributes as CFDictionary)
          if let error = KeychainError.from(status: retryStatus) {
            throw error
          }
        } else if let error = KeychainError.from(status: addStatus) {
          throw error
        }
      } else if let error = KeychainError.from(status: status) {
        throw error
      }
    }
  )

  public static var previewValue: KeychainClient { testValue }

  /// An isolated in-memory Keychain.
  ///
  /// Backed by a fresh dictionary rather than the system Keychain, so tests never touch
  /// real Keychain state and never leak it across tests. swift-dependencies instantiates
  /// `testValue` once per dependency context — i.e. once per test under the `.dependencies`
  /// trait — so each test gets its own store. Keychain-backed `@Shared` values are therefore
  /// isolated by construction: suites that share a key (e.g. a global session) no longer need
  /// `.serialized` to avoid racing on shared global state.
  public static var testValue: KeychainClient {
    let storage = Mutex<[String: Data]>([:])
    return KeychainClient(
      delete: { query in
        storage.withLock { _ = $0.removeValue(forKey: inMemoryStorageKey(for: query)) }
      },
      getData: { query in
        storage.withLock { $0[inMemoryStorageKey(for: query)] }
      },
      setData: { data, query, _ in
        storage.withLock { $0[inMemoryStorageKey(for: query)] = data }
      }
    )
  }
}

/// Derives a stable dictionary key for the in-memory ``KeychainClient/testValue`` from the same
/// item attributes the real Keychain treats as identity: account, service, access group, and
/// synchronizability. Kept in lockstep with `KeychainKey.buildQuery()`.
private func inMemoryStorageKey(for query: [String: Any]) -> String {
  let account = query[kSecAttrAccount as String] as? String ?? ""
  let service = query[kSecAttrService as String] as? String ?? ""
  let accessGroup = query[kSecAttrAccessGroup as String] as? String ?? ""
  let synchronizable = query[kSecAttrSynchronizable as String] != nil
  return "\(service)\u{0}\(account)\u{0}\(accessGroup)\u{0}\(synchronizable)"
}
