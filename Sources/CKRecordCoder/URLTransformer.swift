import CloudKit
import Foundation

enum URLTransformer {
  static func encode(_ value: URL) -> CKRecordValue {
    if value.isFileURL {
      return CKAsset(fileURL: value)
    } else {
      return value.absoluteString as CKRecordValue
    }
  }

  static func decodeMany(record: CKRecord, key: CodingKey, codingPath: [CodingKey]) throws -> [URL]
  {
    if let array = record[key.stringValue] as? [Any] {
      return try array.map { try decodeValue(value: $0, codingPath: codingPath) }
    }
    return []
  }

  static func decodeSingle(record: CKRecord, key: CodingKey, codingPath: [CodingKey]) throws -> URL
  {
    return try decodeValue(value: record[key.stringValue] as Any, codingPath: codingPath)
  }

  private static func decodeValue(value: Any, codingPath: [CodingKey]) throws -> URL {
    if let asset = value as? CKAsset {
      guard let url = asset.fileURL else {
        let context = DecodingError.Context(
          codingPath: codingPath, debugDescription: "CKAsset URL was nil.")
        throw DecodingError.valueNotFound(URL.self, context)
      }
      return url
    }

    guard let str = value as? String else {
      let context = DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "URL should have been encoded as String in CKRecord."
      )
      throw DecodingError.typeMismatch(URL.self, context)
    }

    guard let url = URL(string: str) else {
      let context = DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "The string \(str) is not a valid url."
      )
      throw DecodingError.typeMismatch(URL.self, context)
    }
    return url
  }
}
