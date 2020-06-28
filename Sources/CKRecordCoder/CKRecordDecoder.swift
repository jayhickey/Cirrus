import CloudKit
import Foundation

public final class CKRecordDecoder {

  public func decode<T: Decodable>(_ type: T.Type, from record: CKRecord) throws -> T {
    let decoder = _CKRecordDecoder(record: record)
    return try T(from: decoder)
  }

  public init() {}
}

final class _CKRecordDecoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]

  private var record: CKRecord

  init(record: CKRecord) {
    self.record = record
  }
}

extension _CKRecordDecoder: Decoder {

  func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
    let container = CKRecordKeyedDecodingContainer<Key>(record: record)
    return KeyedDecodingContainer(container)
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    fatalError("Not implemented")
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    fatalError("No implemented")
  }
}
