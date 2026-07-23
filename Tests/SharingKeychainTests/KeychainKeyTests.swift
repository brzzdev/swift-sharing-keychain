import Dependencies
import Foundation
import Sharing
import Synchronization
import Testing

@testable import SharingKeychain

@Suite
struct KeychainKeyTests {
  @Test
  func loadReturnsInitialValueWhenEmpty() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
    } operation: {
      @Shared(.keychain("empty")) var value = "default"
      #expect(value == "default")
    }
  }

  @Test
  func saveAndLoadRoundTrip() throws {
    let store = Mutex<[String: Data]>([:])
    try withDependencies {
      $0.keychainClient.getData = { query in
        let key = query[kSecAttrAccount as String] as! String
        return store.withLock { $0[key] }
      }
      $0.keychainClient.setData = { data, query, _ in
        let key = query[kSecAttrAccount as String] as! String
        store.withLock { $0[key] = data }
      }
    } operation: {
      @Shared(.keychain("token")) var token = ""
      $token.withLock { $0 = "secret123" }
      let stored = store.withLock { $0["token"] }
      #expect(stored != nil)
      let decoded = try JSONDecoder().decode(String.self, from: stored!)
      #expect(decoded == "secret123")
    }
  }

  @Test
  func overwriteExistingValue() {
    let store = Mutex<[String: Data]>([:])
    withDependencies {
      $0.keychainClient.getData = { query in
        let key = query[kSecAttrAccount as String] as! String
        return store.withLock { $0[key] }
      }
      $0.keychainClient.setData = { data, query, _ in
        let key = query[kSecAttrAccount as String] as! String
        store.withLock { $0[key] = data }
      }
    } operation: {
      @Shared(.keychain("counter")) var counter = 0
      $counter.withLock { $0 = 42 }
      $counter.withLock { $0 = 99 }
      let stored = store.withLock { $0["counter"] }
      let decoded = try? JSONDecoder().decode(Int.self, from: stored!)
      #expect(decoded == 99)
    }
  }

  @Test
  func loadExistingValueFromKeychain() throws {
    let existingData = try JSONEncoder().encode("persisted")
    withDependencies {
      $0.keychainClient.getData = { _ in existingData }
    } operation: {
      @Shared(.keychain("existing")) var value = "default"
      #expect(value == "persisted")
    }
  }

  @Test
  func codableStructRoundTrip() {
    struct Credentials: Codable, Equatable, Sendable {
      var password: String
      var username: String
    }

    let store = Mutex<[String: Data]>([:])
    withDependencies {
      $0.keychainClient.getData = { query in
        let key = query[kSecAttrAccount as String] as! String
        return store.withLock { $0[key] }
      }
      $0.keychainClient.setData = { data, query, _ in
        let key = query[kSecAttrAccount as String] as! String
        store.withLock { $0[key] = data }
      }
    } operation: {
      @Shared(.keychain("creds")) var creds = Credentials(password: "", username: "")
      $creds.withLock { $0 = Credentials(password: "s3cret", username: "alice") }
      let stored = store.withLock { $0["creds"] }
      let decoded = try? JSONDecoder().decode(Credentials.self, from: stored!)
      #expect(decoded == Credentials(password: "s3cret", username: "alice"))
    }
  }

  @Test
  func keychainKeyID() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
    } operation: {
      let key1: KeychainKey<String> = .keychain("token", service: "com.app")
      let key2: KeychainKey<String> = .keychain("token", service: "com.app")
      let key3: KeychainKey<String> = .keychain("other", service: "com.app")

      #expect(key1.id == key2.id)
      #expect(key1.id != key3.id)
    }
  }

  @Test
  func keychainKeyIDDifferentServices() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
    } operation: {
      let key1: KeychainKey<String> = .keychain("token", service: "com.app1")
      let key2: KeychainKey<String> = .keychain("token", service: "com.app2")

      #expect(key1.id != key2.id)
    }
  }

  @Test
  func keychainKeyIDDifferentAccessGroups() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
    } operation: {
      let key1: KeychainKey<String> = .keychain(
        "token", accessGroup: "group.a", service: "com.app")
      let key2: KeychainKey<String> = .keychain(
        "token", accessGroup: "group.b", service: "com.app")

      #expect(key1.id != key2.id)
    }
  }

  @Test
  func keychainKeyIDSynchronizableDistinct() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
    } operation: {
      let key1: KeychainKey<String> = .keychain(
        "token", accessibility: .afterFirstUnlock, service: "com.app")
      let key2: KeychainKey<String> = .keychain(
        "token", accessibility: .afterFirstUnlock(synchronizable: true), service: "com.app")

      #expect(key1.id != key2.id)
    }
  }

  @Test
  func settingNilDeletesKeychainItem() {
    let store = Mutex<[String: Data]>([:])
    store.withLock { $0["session"] = try! JSONEncoder().encode("existing") }
    let deletedKeys = Mutex<[String]>([])

    withDependencies {
      $0.keychainClient.getData = { query in
        let key = query[kSecAttrAccount as String] as! String
        return store.withLock { $0[key] }
      }
      $0.keychainClient.setData = { data, query, _ in
        let key = query[kSecAttrAccount as String] as! String
        store.withLock { $0[key] = data }
      }
      $0.keychainClient.delete = { query in
        let key = query[kSecAttrAccount as String] as! String
        deletedKeys.withLock { $0.append(key) }
        store.withLock { $0[key] = nil }
      }
    } operation: {
      @Shared(.keychain("session")) var session: String? = "existing"
      $session.withLock { $0 = nil }
      #expect(deletedKeys.withLock { $0 } == ["session"])
      #expect(store.withLock { $0["session"] } == nil)
    }
  }

  @Test
  func description() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
    } operation: {
      let key: KeychainKey<String> = .keychain("authToken")
      #expect(key.description == ".keychain(\"authToken\")")
    }
  }

  // MARK: - Error paths

  @Test
  func loadDecodingError() {
    withDependencies {
      $0.keychainClient.getData = { _ in Data("not valid json".utf8) }
    } operation: {
      @Shared(.keychain("corrupt")) var value = 42
      #expect($value.loadError != nil)
    }
  }

  @Test
  func loadKeychainError() {
    withDependencies {
      $0.keychainClient.getData = { (_) throws(KeychainError) in throw .interactionNotAllowed }
    } operation: {
      @Shared(.keychain("locked")) var value = ""
      #expect($value.loadError is KeychainError)
    }
  }

  @Test
  func saveKeychainError() async {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
      $0.keychainClient.setData = { (_, _, _) throws(KeychainError) in throw .missingEntitlement }
    } operation: {
      @Shared(.keychain("noEntitlement")) var value = ""
      $value.withLock { $0 = "test" }
      #expect($value.saveError is KeychainError)
    }
  }

  @Test
  func deleteKeychainError() {
    withDependencies {
      $0.keychainClient.getData = { _ in nil }
      $0.keychainClient.delete = { (_) throws(KeychainError) in throw .interactionNotAllowed }
    } operation: {
      @Shared(.keychain("locked")) var value: String? = "existing"
      $value.withLock { $0 = nil }
      #expect($value.saveError is KeychainError)
    }
  }

  // MARK: - KeychainError

  @Test
  func keychainErrorFromStatus() {
    #expect(KeychainError.from(status: errSecSuccess) == nil)
    #expect(KeychainError.from(status: errSecDuplicateItem) == .duplicateItem)
    #expect(KeychainError.from(status: errSecInteractionNotAllowed) == .interactionNotAllowed)
    #expect(KeychainError.from(status: errSecItemNotFound) == .itemNotFound)
    #expect(KeychainError.from(status: errSecMissingEntitlement) == .missingEntitlement)
    #expect(KeychainError.from(status: -99999) == .unexpectedStatus(-99999))
  }

  // MARK: - Accessibility

  @Test
  func accessibilityForwardedToClient() {
    let receivedAccessibility = Mutex<KeychainItemAccessibility?>(nil)

    withDependencies {
      $0.keychainClient.getData = { _ in nil }
      $0.keychainClient.setData = { _, _, accessibility in
        receivedAccessibility.withLock { $0 = accessibility }
      }
    } operation: {
      @Shared(.keychain("secret", accessibility: .whenPasscodeSetThisDeviceOnly)) var secret = ""
      $secret.withLock { $0 = "value" }
      #expect(
        receivedAccessibility.withLock { $0 } == .whenPasscodeSetThisDeviceOnly
      )
    }
  }

  @Test
  func accessibilityMapsToSecAttrConstants() {
    func cf(_ accessibility: KeychainItemAccessibility) -> String { accessibility.cfValue as String }
    #expect(cf(.afterFirstUnlock) == kSecAttrAccessibleAfterFirstUnlock as String)
    #expect(
      cf(.afterFirstUnlockThisDeviceOnly) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    )
    #expect(
      cf(.whenPasscodeSetThisDeviceOnly) == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String
    )
    #expect(cf(.whenUnlocked) == kSecAttrAccessibleWhenUnlocked as String)
    #expect(
      cf(.whenUnlockedThisDeviceOnly) == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
    )
    // The synchronizable form maps to the same accessibility constant.
    #expect(cf(.afterFirstUnlock(synchronizable: true)) == kSecAttrAccessibleAfterFirstUnlock as String)
  }

  @Test
  func synchronizableIsCarriedOnlyBySyncCapableLevels() {
    // Sync is opt-in on the two levels that permit it; false unless explicitly requested.
    #expect(KeychainItemAccessibility.afterFirstUnlock.synchronizable == false)
    #expect(KeychainItemAccessibility.afterFirstUnlock(synchronizable: true).synchronizable == true)
    #expect(KeychainItemAccessibility.whenUnlocked.synchronizable == false)
    #expect(KeychainItemAccessibility.whenUnlocked(synchronizable: true).synchronizable == true)
    // Device-only levels expose no `(synchronizable:)` form, so they can never sync.
    #expect(KeychainItemAccessibility.afterFirstUnlockThisDeviceOnly.synchronizable == false)
    #expect(KeychainItemAccessibility.whenUnlockedThisDeviceOnly.synchronizable == false)
    #expect(KeychainItemAccessibility.whenPasscodeSetThisDeviceOnly.synchronizable == false)
  }

  // MARK: - Query construction

  @Test
  func queryIncludesAccessGroup() {
    let receivedAccessGroup = Mutex<String?>(nil)
    let receivedService = Mutex<String?>(nil)

    withDependencies {
      $0.keychainClient.getData = { query in
        receivedAccessGroup.withLock { $0 = query[kSecAttrAccessGroup as String] as? String }
        receivedService.withLock { $0 = query[kSecAttrService as String] as? String }
        return nil
      }
    } operation: {
      @Shared(.keychain("key", accessGroup: "group.shared", service: "com.app")) var value = ""
      _ = value
      #expect(receivedAccessGroup.withLock { $0 } == "group.shared")
      #expect(receivedService.withLock { $0 } == "com.app")
    }
  }

  @Test
  func queryIncludesSynchronizable() {
    let receivedSynchronizable = Mutex<Bool>(false)

    withDependencies {
      $0.keychainClient.getData = { query in
        let value = query[kSecAttrSynchronizable as String]
        receivedSynchronizable.withLock { $0 = value != nil }
        return nil
      }
    } operation: {
      @Shared(.keychain("key", accessibility: .whenUnlocked(synchronizable: true), service: "com.app"))
      var value = ""
      _ = value
      #expect(receivedSynchronizable.withLock { $0 })
    }
  }

  @Test
  func queryOmitsAccessGroupWhenNil() {
    let hasAccessGroup = Mutex<Bool>(false)

    withDependencies {
      $0.keychainClient.getData = { query in
        hasAccessGroup.withLock { $0 = query[kSecAttrAccessGroup as String] != nil }
        return nil
      }
    } operation: {
      @Shared(.keychain("key", service: "com.app")) var value = ""
      _ = value
      #expect(!hasAccessGroup.withLock { $0 })
    }
  }

  @Test
  func queryOmitsSynchronizableWhenFalse() {
    let hasSynchronizable = Mutex<Bool>(false)

    withDependencies {
      $0.keychainClient.getData = { query in
        hasSynchronizable.withLock { $0 = query[kSecAttrSynchronizable as String] != nil }
        return nil
      }
    } operation: {
      @Shared(.keychain("key", accessibility: .whenUnlocked, service: "com.app")) var value = ""
      _ = value
      #expect(!hasSynchronizable.withLock { $0 })
    }
  }

  // MARK: - Notifications / Subscribe

  @Test
  func subscriberReceivesUpdatesFromAnotherShared() {
    let store = Mutex<[String: Data]>([:])
    withDependencies {
      $0.keychainClient.getData = { query in
        let key = query[kSecAttrAccount as String] as! String
        return store.withLock { $0[key] }
      }
      $0.keychainClient.setData = { data, query, _ in
        let key = query[kSecAttrAccount as String] as! String
        store.withLock { $0[key] = data }
      }
    } operation: {
      @Shared(.keychain("sync", service: "com.test")) var value1 = 0
      @Shared(.keychain("sync", service: "com.test")) var value2 = 0

      $value1.withLock { $0 = 42 }
      #expect(value2 == 42)
    }
  }

  // MARK: - testValue

  @Test
  func testValueWorksWithoutOverrides() {
    withDependencies {
      $0.keychainClient = .testValue
    } operation: {
      @Shared(.keychain("token", service: "com.test.testValue")) var token = ""
      $token.withLock { $0 = "abc" }
      #expect(token == "abc")
    }
  }

  @Test
  func testValueDeletesOnNil() {
    withDependencies {
      $0.keychainClient = .testValue
    } operation: {
      @Shared(.keychain("session", service: "com.test.testValueDelete")) var session: String? = nil
      $session.withLock { $0 = "active" }
      #expect(session == "active")
      $session.withLock { $0 = nil }
      #expect(session == nil)
    }
  }

  @Test
  func testValueRoundTripsThroughAnInMemoryStore() throws {
    let client = KeychainClient.testValue
    let query: [String: Any] = [
      kSecAttrAccount as String: "token",
      kSecAttrService as String: "com.test",
      kSecClass as String: kSecClassGenericPassword,
    ]

    // The old no-op testValue returned nil here even after a write; a real store round-trips.
    #expect(try client.getData(query) == nil)
    try client.setData(Data("secret".utf8), query, .afterFirstUnlock)
    #expect(try client.getData(query) == Data("secret".utf8))
    try client.delete(query)
    #expect(try client.getData(query) == nil)
  }

  @Test
  func testValueInstancesAreIsolated() throws {
    // Each `.testValue` is backed by its own store, so state never leaks between instances —
    // which is what gives per-test isolation once swift-dependencies vends a fresh testValue
    // per test context, removing any need to serialize suites that share a key.
    let first = KeychainClient.testValue
    let second = KeychainClient.testValue
    let query: [String: Any] = [
      kSecAttrAccount as String: "session",
      kSecAttrService as String: "com.test",
      kSecClass as String: kSecClassGenericPassword,
    ]

    try first.setData(Data([0x01]), query, .afterFirstUnlock)

    #expect(try first.getData(query) == Data([0x01]))
    #expect(try second.getData(query) == nil)
  }
}
