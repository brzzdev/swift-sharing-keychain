import Security

/// Controls when a Keychain item can be accessed, and — for the two levels that permit it —
/// whether the item synchronises across devices via iCloud Keychain.
///
/// Apple rejects synchronisation for any accessibility level whose name ends in `ThisDeviceOnly`,
/// so `synchronizable` is offered only on ``afterFirstUnlock`` and ``whenUnlocked``. The three
/// device-only levels have no `synchronizable` variant, which makes the invalid combination
/// impossible to express rather than a runtime `errSecParam` failure.
public struct KeychainItemAccessibility: Sendable, Hashable {
  private enum Base: Sendable, Hashable {
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
  }

  private let base: Base

  /// Whether the item syncs via iCloud Keychain. Always `false` for device-only levels.
  let synchronizable: Bool

  private init(base: Base, synchronizable: Bool) {
    self.base = base
    self.synchronizable = synchronizable
  }

  /// The item is accessible after the first unlock of the device. Recommended for most use cases,
  /// including background tasks.
  public static let afterFirstUnlock = Self(base: .afterFirstUnlock, synchronizable: false)

  /// ``afterFirstUnlock``, optionally synchronised across devices via iCloud Keychain.
  public static func afterFirstUnlock(synchronizable: Bool) -> Self {
    Self(base: .afterFirstUnlock, synchronizable: synchronizable)
  }

  /// Same as ``afterFirstUnlock`` but the item cannot migrate to a new device via backup.
  public static let afterFirstUnlockThisDeviceOnly = Self(
    base: .afterFirstUnlockThisDeviceOnly, synchronizable: false)

  /// The item is only accessible when the device has a passcode set and is unlocked.
  /// Items are deleted if the passcode is removed.
  public static let whenPasscodeSetThisDeviceOnly = Self(
    base: .whenPasscodeSetThisDeviceOnly, synchronizable: false)

  /// The item is only accessible while the device is unlocked.
  public static let whenUnlocked = Self(base: .whenUnlocked, synchronizable: false)

  /// ``whenUnlocked``, optionally synchronised across devices via iCloud Keychain.
  public static func whenUnlocked(synchronizable: Bool) -> Self {
    Self(base: .whenUnlocked, synchronizable: synchronizable)
  }

  /// Same as ``whenUnlocked`` but the item cannot migrate to a new device via backup.
  public static let whenUnlockedThisDeviceOnly = Self(
    base: .whenUnlockedThisDeviceOnly, synchronizable: false)

  var cfValue: CFString {
    switch base {
    case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock
    case .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    case .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    case .whenUnlocked: kSecAttrAccessibleWhenUnlocked
    case .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
  }
}
