import CloudKit
import CloudKitCodable
import Foundation

extension CloudKitCodable {
  var cloudKitRecordType: CKRecord.RecordType {
    return String(describing: type(of: self))
  }
}
