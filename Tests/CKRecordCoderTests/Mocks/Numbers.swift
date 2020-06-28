import CloudKit
import CloudKitCodable
import Foundation

struct Numbers: CloudKitCodable {
  var cloudKitSystemFields: Data?
  var cloudKitIdentifier: String
  var favorites: [Int]

  static func resolveConflict(clientModel clientRecord: Numbers, serverModel serverRecord: Numbers)
    -> Numbers?
  {
    return nil
  }
}

extension Numbers {
  static var numbersMock = Numbers(
    cloudKitSystemFields: nil,
    cloudKitIdentifier: UUID().uuidString,
    favorites: [1, 2, 3, 4]
  )

  static var testIdentifier = "8B14FD76-EA56-49B0-A184-6C01828BA20A"

  static var testZoneID = CKRecordZone.ID(
    zoneName: String(describing: Numbers.self),
    ownerName: CKCurrentUserDefaultName
  )

  static var testRecordID = CKRecord.ID(
    recordName: Numbers.testIdentifier,
    zoneID: Numbers.testZoneID
  )

  static var testRecord = CKRecord(
    recordType: String(describing: Numbers.self),
    recordID: Numbers.testRecordID
  )
}
