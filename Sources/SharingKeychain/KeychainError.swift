public import Security

/// Errors that can occur during Keychain operations.
public enum KeychainError: Error, Sendable, Equatable {
  case decodingFailed(String)
  case duplicateItem
  case encodingFailed(String)
  case interactionNotAllowed
  case itemNotFound
  case missingEntitlement
  case unexpectedStatus(OSStatus)

  static func from(status: OSStatus) -> KeychainError? {
    switch status {
    case errSecSuccess: nil
    case errSecDuplicateItem: .duplicateItem
    case errSecInteractionNotAllowed: .interactionNotAllowed
    case errSecItemNotFound: .itemNotFound
    case errSecMissingEntitlement: .missingEntitlement
    default: .unexpectedStatus(status)
    }
  }
}
