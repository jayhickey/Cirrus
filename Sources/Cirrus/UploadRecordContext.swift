@_implementationOnly import CKRecordCoder
import CloudKit
import CloudKitCodable
import Foundation
import os.log

final class UploadRecordContext<Persistable: CloudKitCodable>: RecordModifyingContext {

  private let defaults: UserDefaults
  private let zoneID: CKRecordZone.ID
  private let logHandler: (String, OSLogType) -> Void

  private lazy var uploadBufferKey = "UPLOADBUFFER-\(zoneID.zoneName))"

  init(
    defaults: UserDefaults, zoneID: CKRecordZone.ID,
    logHandler: @escaping (String, OSLogType) -> Void
  ) {
    self.defaults = defaults
    self.zoneID = zoneID
    self.logHandler = logHandler
  }

  func buffer(_ values: [Persistable]) {
    let records: [CKRecord]
    do {
      records = try values.map { try CKRecordEncoder(zoneID: zoneID).encode($0) }
    } catch let error {
      logHandler("Failed to encode records for upload: \(String(describing: error))", .error)
      records = values.compactMap { try? CKRecordEncoder(zoneID: zoneID).encode($0) }
    }
    records.forEach { recordsToSave[$0.recordID] = $0 }
  }

  func removeFromBuffer(_ values: [Persistable]) {
    let records = values.compactMap { try? CKRecordEncoder(zoneID: zoneID).encode($0) }
    records.forEach { recordsToSave.removeValue(forKey: $0.recordID) }
  }

  // MARK: - RecordModifying

  let name = "upload"
  let savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged

  var recordsToSave: [CKRecord.ID: CKRecord] {
    get {
      guard let data = defaults.data(forKey: uploadBufferKey) else { return [:] }
      do {
        return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
          as? [CKRecord.ID: CKRecord] ?? [:]
      } catch {
        logHandler("Failed to decode CKRecord.IDs from defaults key uploadBufferKey", .error)
        return [:]
      }
    }
    set {
      do {
        logHandler("Updating \(self.name) buffer with \(newValue.count) items", .info)
        let data = try NSKeyedArchiver.archivedData(
          withRootObject: newValue, requiringSecureCoding: true)
        defaults.set(data, forKey: uploadBufferKey)
      } catch {
        logHandler("Failed to encode record ids for upload: \(String(describing: error))", .error)
      }
    }
  }

  var recordIDsToDelete: [CKRecord.ID] = []

  func modelChangeForUpdatedRecords<T: CloudKitCodable>(
    recordsSaved: [CKRecord], recordIDsDeleted: [CKRecord.ID]
  ) -> SyncEngine<T>.ModelChange {
    let models: Set<T> = Set(
      recordsSaved.compactMap { record in
        do {
          let decoder = CKRecordDecoder()
          return try decoder.decode(T.self, from: record)
        } catch {
          logHandler("Error decoding item from record: \(String(describing: error))", .error)
          return nil
        }
      })

    recordsSaved.forEach { recordsToSave.removeValue(forKey: $0.recordID) }

    return .updated(models)
  }

  func failedToUpdateRecords(recordsSaved: [CKRecord], recordIDsDeleted: [CKRecord.ID]) {
    recordsSaved.forEach { recordsToSave.removeValue(forKey: $0.recordID) }
  }
}
