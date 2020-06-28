import CloudKit
import CloudKitCodable
import Foundation

struct Person: CloudKitCodable {
  enum Access: String, Codable {
    case admin
    case user
  }

  var cloudKitSystemFields: Data?
  var cloudKitIdentifier: String
  var name: String? = "George Michael"
  var age: Int? = 22
  var website = URL(string: "https://blueman.com")
  var twitter: URL? = nil
  var avatar: URL? = URL(fileURLWithPath: "/path/to/file")
  var isDeveloper: Bool? = false
  var access: Access? = .user

  static func resolveConflict(clientModel clientRecord: Person, serverModel serverRecord: Person)
    -> Person?
  {
    return nil
  }
}

extension Person {
  static let personWithSystemFields = Person(
    cloudKitSystemFields: Person.systemFieldsDataForTesting,
    cloudKitIdentifier: Person.testIdentifier,
    name: "Tobias Funke",
    age: 50,
    website: URL(string: "https://blueman.com")!,
    twitter: nil,
    avatar: URL(fileURLWithPath: "/path/to/file"),
    isDeveloper: true,
    access: .admin
  )

  static var testIdentifier = "29C1D1AD-18E0-47C1-B064-265D2458E650"

  static var testZoneID = CKRecordZone.ID(
    zoneName: String(describing: Person.self),
    ownerName: CKCurrentUserDefaultName
  )

  static var testRecordID = CKRecord.ID(
    recordName: Person.testIdentifier,
    zoneID: Person.testZoneID
  )

  static var testRecord = CKRecord(
    recordType: String(describing: Person.self),
    recordID: Person.testRecordID
  )

  static var systemFieldsDataForTesting: Data {
    let coder = NSKeyedArchiver(requiringSecureCoding: true)
    Person.testRecord.encodeSystemFields(with: coder)
    coder.finishEncoding()
    return coder.encodedData
  }
}
