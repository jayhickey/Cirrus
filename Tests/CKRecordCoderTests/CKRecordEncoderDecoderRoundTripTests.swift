import CloudKit
import XCTest

@testable import CKRecordCoder

class CKRecordEncoderDecoderRoundTripTests: XCTestCase {

  func testRoundTripWithCustomIdentifier() throws {
    let bookmark = Bookmark.bookmarkWithoutSystemFields

    let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: "12345")
    let encoder = CKRecordEncoder(zoneID: zoneID)

    let bookmarkRecord = try encoder.encode(bookmark)

    let decodedBookmark = try CKRecordDecoder().decode(Bookmark.self, from: bookmarkRecord)

    XCTAssertNotEqual(bookmark.cloudKitSystemFields, decodedBookmark.cloudKitSystemFields)
    XCTAssertEqual(Bookmark.testIdentifier, decodedBookmark.cloudKitIdentifier)
    XCTAssertEqual(bookmark.cloudKitRecordType, decodedBookmark.cloudKitRecordType)
    XCTAssertEqual(bookmark.title, decodedBookmark.title)
  }

  func testRoundTripWithSystemFields() throws {
    let person = Person.personWithSystemFields

    let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: "12345")
    let encoder = CKRecordEncoder(zoneID: zoneID)

    let personRecord = try encoder.encode(person)

    let decodedPerson = try CKRecordDecoder().decode(Person.self, from: personRecord)

    XCTAssertEqual(person.cloudKitSystemFields, decodedPerson.cloudKitSystemFields)
    XCTAssertEqual(person.cloudKitRecordType, decodedPerson.cloudKitRecordType)
  }

  func testRoundTripPrimitives() throws {
    let person = Person.personWithSystemFields

    let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: "12345")
    let encoder = CKRecordEncoder(zoneID: zoneID)

    let personRecord = try encoder.encode(person)

    let decodedPerson = try CKRecordDecoder().decode(Person.self, from: personRecord)

    XCTAssertEqual(person.name, decodedPerson.name)
    XCTAssertEqual(person.age, decodedPerson.age)
    XCTAssertEqual(person.website, decodedPerson.website)
    XCTAssertEqual(person.twitter, decodedPerson.twitter)
    XCTAssertEqual(person.isDeveloper, decodedPerson.isDeveloper)
    XCTAssertEqual(person.access, decodedPerson.access)
  }

  func testRoundTripFileURL() throws {
    let person = Person.personWithSystemFields

    let zoneID = CKRecordZone.ID(zoneName: "ABCDE", ownerName: "12345")
    let encoder = CKRecordEncoder(zoneID: zoneID)

    let personRecord = try encoder.encode(person)

    let decodedPerson = try CKRecordDecoder().decode(Person.self, from: personRecord)

    XCTAssertEqual(person.avatar, decodedPerson.avatar)
  }

  func testRoundTripNestedValues() throws {
    let pet = Pet(name: "Buster")
    let child = Child(age: 22, name: "George Michael Bluth", gender: .male, pet: pet)

    let inputParent = Parent(
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
    let record = try encoder.encode(inputParent)

    let parent = try CKRecordDecoder().decode(Parent.self, from: record)

    XCTAssertEqual(parent.child.pet, pet)
    XCTAssertEqual(parent.child, child)
  }

  func testRoundTripLists() throws {
    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )
    let record = try encoder.encode(Numbers.numbersMock)

    let numbers = try CKRecordDecoder().decode(Numbers.self, from: record)

    XCTAssertEqual(numbers.favorites, [1, 2, 3, 4])
  }

  func testRoundTripUUID() throws {
    let inputModel = UUIDModel.uuidModelMock

    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: Person.self),
        ownerName: CKCurrentUserDefaultName
      )
    )

    let record = try encoder.encode(inputModel)

    let model = try CKRecordDecoder().decode(UUIDModel.self, from: record)

    XCTAssertEqual(model.uuid, UUID(uuidString: "0D2E7B29-AC4C-4A04-B57E-5CA0D208E55F")!)
  }

  func testRoundTripURLArray() throws {
    let uuid = UUID()
    let model = URLModel(
      cloudKitIdentifier: uuid.uuidString,
      urls: [
        "http://tkdfeddizkj.pafpapsnrnn.net",
        "http://dcacju.uyczcghcqruf.bg",
        "http://utonggatwhxz.aicwdazc.info",
        "http://kfvbza.zvmoitujnrq.fr",
      ].compactMap(URL.init(string:))
    )

    let encoder = CKRecordEncoder(
      zoneID: CKRecordZone.ID(
        zoneName: String(describing: UUIDModel.self), ownerName: CKCurrentUserDefaultName)
    )

    let data = try encoder.encode(model)

    let decodedModel = try CKRecordDecoder().decode(URLModel.self, from: data)
    XCTAssertEqual(model.urls, decodedModel.urls)
  }
}
