import CKRecordCoder
import CloudKit
import XCTest

class CKRecordDecoderTests: XCTestCase {

  func testDecodingWithSystemFields() throws {
    let record = Person.testRecord
    record["cloudKitIdentifier"] = Person.testIdentifier as CKRecordValue
    record["name"] = "Tobias Funke" as CKRecordValue
    record["age"] = 50 as CKRecordValue
    record["avatar"] = CKAsset(fileURL: URL(fileURLWithPath: "/path/to/file")) as CKRecordValue

    let person = try CKRecordDecoder().decode(Person.self, from: record)

    XCTAssertEqual(person.cloudKitSystemFields!, Person.systemFieldsDataForTesting)
    XCTAssertEqual(person.cloudKitIdentifier, Person.testIdentifier)
  }

  func testDecodingPrimitives() throws {
    let record = Person.testRecord
    record["cloudKitIdentifier"] = Person.testIdentifier as CKRecordValue
    record["name"] = "Tobias Funke" as CKRecordValue
    record["age"] = 50 as CKRecordValue
    record["website"] = "https://blueman.com" as CKRecordValue
    record["twitter"] = nil
    record["isDeveloper"] = true as CKRecordValue
    record["access"] = "user"

    let person = try CKRecordDecoder().decode(Person.self, from: record)

    XCTAssertEqual(person.cloudKitSystemFields!, Person.systemFieldsDataForTesting)
    XCTAssertEqual(person.cloudKitIdentifier, Person.testIdentifier)
    XCTAssertEqual(person.name, "Tobias Funke")
    XCTAssertEqual(person.age, 50)
    XCTAssertEqual(person.website, URL(string: "https://blueman.com")!)
    XCTAssertEqual(person.twitter, nil)
    XCTAssertEqual(person.isDeveloper, true)
    XCTAssertEqual(person.access, .user)
  }

  func testDecodingFileURL() throws {
    let record = Person.testRecord
    record["cloudKitIdentifier"] = Person.testIdentifier as CKRecordValue
    record["avatar"] = CKAsset(fileURL: URL(fileURLWithPath: "/path/to/file")) as CKRecordValue

    let person = try CKRecordDecoder().decode(Person.self, from: record)

    XCTAssertEqual(person.avatar, URL(fileURLWithPath: "/path/to/file"))
  }

  func testDecodingNestedValues() throws {
    let pet = Pet(name: "Buster")
    let child = Child(age: 22, name: "George Michael Bluth", gender: .male, pet: pet)

    let record = Parent.testRecord
    record["name"] = "Michael Bluth"
    record["cloudKitIdentifier"] = Parent.testIdentifier as CKRecordValue
    record["child"] = try? JSONEncoder().encode(child)

    let parent = try CKRecordDecoder().decode(Parent.self, from: record)

    XCTAssertEqual(parent.child.pet, pet)
    XCTAssertEqual(parent.child, child)
  }

  func testDecodingLists() throws {
    let record = Numbers.testRecord
    record["cloudKitIdentifier"] = Numbers.testIdentifier as CKRecordValue
    record["favorites"] = [1, 2, 3, 4]

    let numbers = try CKRecordDecoder().decode(Numbers.self, from: record)

    XCTAssertEqual(numbers.favorites, [1, 2, 3, 4])
  }

  func testDecodingUUID() throws {
    let record = CKRecord(recordType: "UUIDModel")
    record["cloudKitIdentifier"] = UUID().uuidString as CKRecordValue
    record["uuid"] = try JSONEncoder().encode(
      UUID(uuidString: "0D2E7B29-AC4C-4A04-B57E-5CA0D208E55F"))

    let model = try CKRecordDecoder().decode(UUIDModel.self, from: record)

    XCTAssertEqual(model.uuid, UUID(uuidString: "0D2E7B29-AC4C-4A04-B57E-5CA0D208E55F")!)
  }

  func testDecodingURLArray() throws {
    let record = CKRecord(recordType: "URLModel")
    record["cloudKitIdentifier"] = try JSONEncoder().encode(UUID().uuidString)
    record["urls"] = [
      "http://tkdfeddizkj.pafpapsnrnn.net",
      "http://dcacju.uyczcghcqruf.bg",
      "http://utonggatwhxz.aicwdazc.info",
      "http://kfvbza.zvmoitujnrq.fr",
    ]

    let model = try CKRecordDecoder().decode(URLModel.self, from: record)
    XCTAssertEqual(model.urls.map { $0.absoluteString }, record["urls"])
  }
}
