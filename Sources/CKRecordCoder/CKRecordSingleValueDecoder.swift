import CloudKit
import Foundation

enum CKRecordSingleValueDecodingError: Error {
  case codingPathMissing
  case unableToDecode
}

final class CKRecordSingleValueDecoder: Decoder {
  private var record: CKRecord
  var codingPath: [CodingKey]
  var userInfo: [CodingUserInfoKey: Any] = [:]

  init(record: CKRecord, codingPath: [CodingKey]) {
    self.record = record
    self.codingPath = codingPath
  }

  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
  where Key: CodingKey {
    return KeyedDecodingContainer(DummyKeyedDecodingContainer())
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    return DummyUnkeyedDecodingContainer()
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    var container = SingleCKRecordValueDecodingContainer(record: record)
    container.codingPath = codingPath
    return container
  }
}

struct SingleCKRecordValueDecodingContainer: SingleValueDecodingContainer {
  var codingPath: [CodingKey] = []
  var record: CKRecord

  func decodeNil() -> Bool {
    guard let key = codingPath.first else { return true }
    guard let _ = record[key.stringValue] else { return true }
    return false
  }

  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    guard let key = codingPath.first else {
      throw CKRecordSingleValueDecodingError.codingPathMissing
    }
    guard let value = record[key.stringValue] as? T else {
      throw CKRecordSingleValueDecodingError.unableToDecode
    }
    return value
  }
}

struct DummyKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  var codingPath: [CodingKey] = []
  var allKeys: [Key] = []

  func contains(_ key: Key) -> Bool { return true }

  func decodeNil(forKey key: Key) throws -> Bool {
    throw CKRecordSingleValueDecodingError.unableToDecode
  }

  func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
    throw CKRecordSingleValueDecodingError.unableToDecode
  }

  func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type,
    forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    fatalError("Not implemented")
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    fatalError("Not implemented")
  }

  func superDecoder() throws -> Decoder { fatalError("Not implemented") }

  func superDecoder(forKey key: Key) throws -> Decoder { fatalError("Not implemented") }
}

struct DummyUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  var codingPath: [CodingKey] = []
  var count: Int? = nil
  var isAtEnd: Bool = true
  var currentIndex: Int = 0

  mutating func decodeNil() throws -> Bool { throw CKRecordSingleValueDecodingError.unableToDecode }

  mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    throw CKRecordSingleValueDecodingError.unableToDecode
  }

  mutating func nestedContainer<NestedKey>(
    keyedBy type: NestedKey.Type
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    fatalError("Not implemented")
  }

  mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    fatalError("Not implemented")
  }

  mutating func superDecoder() throws -> Decoder { fatalError("Not implemented") }
}
