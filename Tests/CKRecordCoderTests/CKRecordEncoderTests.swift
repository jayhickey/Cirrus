import CloudKit
import XCTest

@testable import CKRecordCoder

class CKRecordEncoderTests: XCTestCase {

  func testEncodingWithSystemFields() throws {
    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(Person.personWithSystemFields)

    XCTAssertEqual(record.recordID, Person.testRecordID)
    XCTAssertEqual(record.recordType, "Person")
    XCTAssertEqual(record["cloudKitIdentifier"], Person.testIdentifier)

    XCTAssertNil(
      record[_CloudKitSystemFieldsKeyName],
      "\(_CloudKitSystemFieldsKeyName) should NOT be encoded to the record directly"
    )
  }

  func testEncodingPrimitives() throws {
    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(Person.personWithSystemFields)

    XCTAssertEqual(record["name"] as? String, "Tobias Funke")
    XCTAssertEqual(record["age"] as? Int, 50)
    XCTAssertEqual(record["website"] as? String, "https://blueman.com")
    XCTAssertEqual(record["isDeveloper"] as? Bool, true)
    XCTAssertEqual(record["access"] as? String, "admin")
    XCTAssertNil(record["twitter"])
  }

  func testEncodingFileURL() throws {
    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(Person.personWithSystemFields)

    guard let asset = record["avatar"] as? CKAsset else {
      XCTFail("URL property with file url should encode to CKAsset.")
      return
    }
    XCTAssertEqual(asset.fileURL?.path, "/path/to/file")
  }

  func testEncodingWithoutSystemFields() throws {
    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Bookmark.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(Bookmark.bookmarkWithoutSystemFields)

    XCTAssertEqual(
      record.recordID,
      CKRecord.ID(
        recordName: Bookmark.testIdentifier,
        zoneID: CKRecordZone.ID(
          zoneName: String(describing: Bookmark.self),
          ownerName: CKCurrentUserDefaultName
        )
      )
    )
    XCTAssertEqual(record["title"], "Apple")
  }

  func testEncodingNestedValues() throws {
    let pet = Pet(name: "Buster")
    let child = Child(age: 22, name: "George Michael Bluth", gender: .male, pet: pet)

    let parent = Parent(
      cloudKitSystemFields: nil,
      cloudKitIdentifier: UUID().uuidString,
      name: "Michael Bluth",
      child: child
    )

    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(parent)

    XCTAssertEqual(record["name"], "Michael Bluth")
    XCTAssertEqual(record["child"], try JSONEncoder().encode(child))
  }

  func testEncodingLists() throws {
    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(Numbers.numbersMock)
    XCTAssertEqual(record["favorites"], [1, 2, 3, 4])
  }

  func testEncodingUUID() throws {
    let model = UUIDModel.uuidModelMock

    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )

    let record = try encoder.encode(model)

    XCTAssertEqual(record["uuid"], model.uuid.uuidString)
  }

  func testEncodingURLArray() throws {
    let model = URLModel(
      cloudKitIdentifier: UUID().uuidString,
      urls: [
        "http://tkdfeddizkj.pafpapsnrnn.net",
        "http://dcacju.uyczcghcqruf.bg",
        "http://utonggatwhxz.aicwdazc.info",
        "http://kfvbza.zvmoitujnrq.fr",
      ].compactMap(URL.init(string:))
    )

    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(model)
    let urls = (record["urls"] as! [CKRecordValue])
      .compactMap { $0 as? String }
      .compactMap({ URL(string: $0) })

    XCTAssertEqual(urls.count, model.urls.count)
  }

}
