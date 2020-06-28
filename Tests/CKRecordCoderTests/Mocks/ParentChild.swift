import CloudKit
import CloudKitCodable
import Foundation

struct Parent: CloudKitCodable {
  var cloudKitSystemFields: Data?
  var cloudKitIdentifier: String
  var name: String
  var child: Child
  static func resolveConflict(clientModel: Parent, serverModel: Parent) -> Parent? {
    nil
  }
}

struct Child: Codable, Hashable {
  let age: Int
  let name: String
  let gender: Gender
  let pet: Pet?
}

struct Pet: Codable, Hashable {
  let name: String
}

enum Gender: Int, Codable {
  case male
  case female
}

extension Parent {
  static var testIdentifier = "4DA396F5-9903-4565-AED1-24E16164A479"

  static var testZoneID = CKRecordZone.ID(
    zoneName: String(describing: Parent.self),
    ownerName: CKCurrentUserDefaultName
  )

  static var testRecordID = CKRecord.ID(
    recordName: Parent.testIdentifier,
    zoneID: Parent.testZoneID
  )

  static var testRecord = CKRecord(
    recordType: String(describing: Parent.self),
    recordID: Parent.testRecordID
  )
}
