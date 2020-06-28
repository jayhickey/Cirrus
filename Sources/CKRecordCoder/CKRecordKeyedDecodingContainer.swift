import CloudKit
import Foundation

final class CKRecordKeyedDecodingContainer<Key: CodingKey> {
  var record: CKRecord
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  lazy var jsonDecoder: JSONDecoder = {
    return JSONDecoder()
  }()

  init(record: CKRecord) {
    self.record = record
  }

  private lazy var systemFieldsData: Data = {
    return encodeSystemFields()
  }()

  func nestedCodingPath(forKey key: CodingKey) -> [CodingKey] {
    return self.codingPath + [key]
  }
}

extension CKRecordKeyedDecodingContainer: KeyedDecodingContainerProtocol {
  var allKeys: [Key] {
    return self.record.allKeys().compactMap { Key(stringValue: $0) }
  }

  func contains(_ key: Key) -> Bool {
    // CKRecord does not contain a key that represents the system field information. The system fields data
    // must be extracted separately. Returning true here tells the decoder that we can extract this value.
    guard key.stringValue != _CloudKitSystemFieldsKeyName else { return true }

    // All other keys must be present in the CKRecord in order to be decoded.
    return allKeys.contains(where: { $0.stringValue == key.stringValue })
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    if key.stringValue == _CloudKitSystemFieldsKeyName {
      return systemFieldsData.count == 0
    } else {
      return record[key.stringValue] == nil
    }
  }

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    // Extract system fields data from CKRecord.
    if key.stringValue == _CloudKitSystemFieldsKeyName {
      return systemFieldsData as! T
    } else if type == URL.self {
      return try URLTransformer.decodeSingle(record: record, key: key, codingPath: codingPath) as! T
    } else if type == [URL].self {
      return try URLTransformer.decodeMany(record: record, key: key, codingPath: codingPath) as! T
    } else if let value = record[key.stringValue] as? T {
      return value
    } else if let value = record[key.stringValue] as? Data,
      let decodedValue = try? jsonDecoder.decode(type, from: value)
    {
      return decodedValue
    }

    let decoder = CKRecordSingleValueDecoder(record: record, codingPath: codingPath + [key])
    guard let decodedValue = try? type.init(from: decoder) else {
      let context = DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Value could not be decoded for key \(key)."
      )
      throw DecodingError.typeMismatch(type, context)
    }

    return decodedValue
  }

  func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
    -> KeyedDecodingContainer<NestedKey>
  {
    fatalError("Not implemented")
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    fatalError("Not implemented")
  }

  func superDecoder() throws -> Decoder {
    return _CKRecordDecoder(record: record)
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    let decoder = _CKRecordDecoder(record: record)
    decoder.codingPath = [key]
    return decoder
  }

  private func encodeSystemFields() -> Data {
    let coder = NSKeyedArchiver(requiringSecureCoding: true)
    record.encodeSystemFields(with: coder)
    coder.finishEncoding()
    return coder.encodedData
  }
}
