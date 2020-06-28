import CloudKit
import Foundation

extension CloudKitCodable {
  /// The time when the record was last saved to the server.
  public var cloudKitLastModifiedDate: Date? {
    guard let data = cloudKitSystemFields,
      let coder = try? NSKeyedUnarchiver(forReadingFrom: data)
    else { return nil }
    coder.requiresSecureCoding = true
    let record = CKRecord(coder: coder)
    coder.finishDecoding()
    return record?.modificationDate
  }
}
