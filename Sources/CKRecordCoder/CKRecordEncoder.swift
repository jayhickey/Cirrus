import CloudKit
import CloudKitCodable
import Foundation

public final class CKRecordEncoder {
  // The maximum amount of data that can be stored by a record (1 MB)
  private let maximumAllowedRecordSizeInBytes: Int = 1 * 1024 * 1024

  public var zoneID: CKRecordZone.ID

  public init(zoneID: CKRecordZone.ID) {
    self.zoneID = zoneID
  }

  public func encode<E: CloudKitCodable>(_ value: E) throws -> CKRecord {
    let type = value.cloudKitRecordType
    let recordName = value.cloudKitIdentifier

    let encoder = _CKRecordEncoder(
      recordTypeName: type,
      recordName: recordName,
      zoneID: zoneID
    )

    try value.encode(to: encoder)

    let record = encoder.buildRecord()

    try validateSize(for: encoder.storage.keys)

    return record
  }

  public static func decodeSystemFields(with systemFields: Data) -> CKRecord? {
    guard let coder = try? NSKeyedUnarchiver(forReadingFrom: systemFields) else { return nil }
    coder.requiresSecureCoding = true
    let record = CKRecord(coder: coder)
    coder.finishDecoding()
    return record
  }

  private func validateSize(for recordKeyValues: [String: CKRecordValue]) throws {
    guard
      let recordData = try? NSKeyedArchiver.archivedData(
        withRootObject: recordKeyValues,
        requiringSecureCoding: true
      )
    else { return }

    if recordData.count >= maximumAllowedRecordSizeInBytes {
      let context = EncodingError.Context(
        codingPath: [],
        debugDescription:
          "CKRecord is too large. Record is \(formattedSize(ofDataCount: recordData.count)), the maxmimum allowed size is \(formattedSize(ofDataCount: maximumAllowedRecordSizeInBytes)))"
      )
      throw EncodingError.invalidValue(Any.self, context)
    }
  }

  private func formattedSize(ofDataCount dataCount: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: Int64(dataCount))
  }
}

final class _CKRecordEncoder {
  let recordTypeName: CKRecord.RecordType
  let recordName: String
  let zoneID: CKRecordZone.ID
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]

  var storage: Storage

  init(
    recordTypeName: CKRecord.RecordType,
    recordName: String,
    zoneID: CKRecordZone.ID,
    storage: Storage = Storage()
  ) {
    self.recordTypeName = recordTypeName
    self.recordName = recordName
    self.zoneID = zoneID
    self.storage = storage
  }
}

extension _CKRecordEncoder {
  final class Storage {
    private(set) var record: CKRecord?
    private(set) var keys: [String: CKRecordValue] = [:]

    func set(record: CKRecord?) {
      self.record = record
    }

    func encode(codingPath: [CodingKey], value: CKRecordValue?) {
      let key =
        codingPath
        .map { $0.stringValue }
        .joined(separator: "_")
      keys[key] = value
    }
  }

  func buildRecord() -> CKRecord {
    let output: CKRecord =
      storage.record
      ?? CKRecord(
        recordType: recordTypeName,
        recordID: CKRecord.ID(
          recordName: recordName,
          zoneID: zoneID)
      )

    guard output.recordType == recordTypeName else {
      fatalError(
        """
        CloudKit record type mismatch: the record should be of type \(recordTypeName) but it was
        of type \(output.recordType). This is probably a result of corrupted cloudKitSystemData
        or a change in record/type name that must be corrected in your type by adopting CustomCloudKitEncodable.
        """
      )
    }

    storage.keys.forEach { (key, value) in output[key] = value }
    return output
  }
}

extension _CKRecordEncoder: Encoder {

  func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
    let container = CKRecordKeyedEncodingContainer<Key>(storage: storage)
    container.codingPath = codingPath
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("Not implemented")
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError("Not implemented")
  }
}
