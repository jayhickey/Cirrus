@_implementationOnly import CKRecordCoder
import CloudKit
import CloudKitCodable
import Foundation
import os.log

final class UploadRecordContext<Persistable: CloudKitCodable>: RecordModifyingContext {

  private let defaults: UserDefaults
  private let zoneID: CKRecordZone.ID
  private let log: OSLog

  private lazy var uploadBufferKey = "UPLOADBUFFER-\(zoneID.zoneName))"

  init(defaults: UserDefaults, zoneID: CKRecordZone.ID, log: OSLog) {
    self.defaults = defaults
    self.zoneID = zoneID
    self.log = log
  }

  func buffer(_ values: [Persistable]) {
    let records: [CKRecord]
    do {
      records = try values.map { try CKRecordEncoder(zoneID: zoneID).encode($0) }
    } catch let error {
      os_log(
        "Failed to encode records for upload:  %{public}@", log: log, type: .error,
        String(describing: error))
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
        os_log(
          "Failed to decode CKRecord.IDs from defaults key uploadBufferKey", log: log, type: .error)
        return [:]
      }
    }
    set {
      do {
        os_log(
          "Updating %{public}@ buffer with %d items", log: log, type: .info, name, newValue.count)
        let data = try NSKeyedArchiver.archivedData(
          withRootObject: newValue, requiringSecureCoding: true)
        defaults.set(data, forKey: uploadBufferKey)
      } catch {
        os_log(
          "Failed to encode record ids for upload: %{public}@", log: log, type: .error,
          String(describing: error))
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
          os_log(
            "Error decoding item from record: %{public}@", log: log, type: .error,
            String(describing: error))
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
