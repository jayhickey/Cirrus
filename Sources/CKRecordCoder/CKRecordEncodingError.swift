import Foundation

enum CKRecordEncodingError: Error {
  case unsupportedValueForKey(String)
  case systemFieldsDecode(String)
  case referencesNotSupported(String)

  public var localizedDescription: String {
    switch self {
    case .unsupportedValueForKey(let key):
      return """
        The value of key \(key) is not supported. Only values that can be converted to
        CKRecordValue are supported. Check the CloudKit documentation to see which types
        can be used.
        """
    case .systemFieldsDecode(let info):
      return "Failed to process \(_CloudKitSystemFieldsKeyName): \(info)"
    case .referencesNotSupported(let key):
      return "References are not supported by CKRecordEncoder yet. Key \(key)."
    }
  }
}
