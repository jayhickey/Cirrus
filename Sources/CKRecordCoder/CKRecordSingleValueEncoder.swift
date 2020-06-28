import CloudKit
import Foundation

enum CKRecordSingleValueEncodingError: Error {
  case unableToEncode
}

struct CKRecordSingleValueEncoder: Encoder {
  private var storage: _CKRecordEncoder.Storage
  var codingPath: [CodingKey]
  var userInfo: [CodingUserInfoKey: Any] = [:]

  init(storage: _CKRecordEncoder.Storage, codingPath: [CodingKey]) {
    self.storage = storage
    self.codingPath = codingPath
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    return KeyedEncodingContainer(DummyKeyedEncodingContainer())
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    return DummyUnkeyedCodingContainer()
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    var container = SingleCKRecordValueEncodingContainer(storage: storage)
    container.codingPath = codingPath
    return container
  }
}

struct SingleCKRecordValueEncodingContainer: SingleValueEncodingContainer {
  var storage: _CKRecordEncoder.Storage
  var codingPath: [CodingKey] = []

  mutating func encodeNil() throws {
    storage.encode(codingPath: codingPath, value: nil)
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    guard let value = value as? CKRecordValue else {
      throw CKRecordSingleValueEncodingError.unableToEncode
    }
    storage.encode(codingPath: codingPath, value: value)
  }
}

struct DummyKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  var codingPath: [CodingKey] = []

  mutating func encodeNil(forKey key: Key) throws {
    throw CKRecordSingleValueEncodingError.unableToEncode
  }

  mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
    throw CKRecordSingleValueEncodingError.unableToEncode
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    fatalError("Not implemented")
  }

  mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    fatalError("Not implemented")
  }

  mutating func superEncoder() -> Encoder {
    fatalError("Not implemented")
  }

  mutating func superEncoder(forKey key: Key) -> Encoder {
    fatalError("Not implemented")
  }
}

struct DummyUnkeyedCodingContainer: UnkeyedEncodingContainer {
  var codingPath: [CodingKey] = []
  var count: Int = 0

  mutating func encodeNil() throws {
    throw CKRecordSingleValueEncodingError.unableToEncode
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    throw CKRecordSingleValueEncodingError.unableToEncode
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    fatalError("Not implemented")
  }

  mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("Not implemented")
  }

  mutating func superEncoder() -> Encoder {
    fatalError("Not implemented")
  }
}
