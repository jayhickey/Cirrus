import CloudKit
import CloudKitCodable
import Foundation

final class CKRecordKeyedEncodingContainer<Key: CodingKey> {
  var storage: _CKRecordEncoder.Storage
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  lazy var jsonEncoder: JSONEncoder = {
    return JSONEncoder()
  }()

  init(storage: _CKRecordEncoder.Storage) {
    self.storage = storage
  }
}

extension CKRecordKeyedEncodingContainer: KeyedEncodingContainerProtocol {
  func encodeNil(forKey key: Key) throws {
    storage.encode(codingPath: codingPath + [key], value: nil)
  }

  func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
    guard !(value is CloudKitEncodable) && !(value is [CloudKitEncodable]) else {
      throw CKRecordEncodingError.referencesNotSupported(
        codingPath.map { $0.stringValue }.joined(separator: "-"))
    }

    if key.stringValue == _CloudKitSystemFieldsKeyName {
      guard let systemFieldsData = value as? Data else {
        throw CKRecordEncodingError.systemFieldsDecode(
          "\(_CloudKitSystemFieldsKeyName) property must be of type Data.")
      }
      storage.set(record: CKRecordEncoder.decodeSystemFields(with: systemFieldsData))
    } else if let value = value as? URL {
      storage.encode(codingPath: codingPath + [key], value: URLTransformer.encode(value))
    } else if let value = value as? [URL] {
      storage.encode(
        codingPath: codingPath + [key], value: value.map(URLTransformer.encode) as CKRecordValue)
    } else if let value = value as? CKRecordValue {
      storage.encode(codingPath: codingPath + [key], value: value)
    } else {
      do {
        let encoder = CKRecordSingleValueEncoder(storage: storage, codingPath: codingPath + [key])
        try value.encode(to: encoder)
      } catch {
        storage.encode(
          codingPath: codingPath + [key], value: try jsonEncoder.encode(value) as CKRecordValue)
      }
    }
  }

  func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    fatalError("Not implemented")
  }

  func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    fatalError("Not implemented")
  }

  func superEncoder() -> Encoder {
    fatalError("Not implemented")
  }

  func superEncoder(forKey key: Key) -> Encoder {
    fatalError("Not implemented")
  }
}
