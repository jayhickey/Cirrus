@_implementationOnly import CKRecordCoder
import CloudKit
import CloudKitCodable
import Foundation
import os.log

extension SyncEngine {

  // MARK: - Internal

  func fetchRemoteChanges() {
    os_log("%{public}@", log: log, type: .debug, #function)

    var changedRecords: [CKRecord] = []
    var deletedRecordIDs: [CKRecord.ID] = []

    let operation = CKFetchRecordZoneChangesOperation()

    let token: CKServerChangeToken? = privateChangeToken

    let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
      previousServerChangeToken: token,
      resultsLimit: nil,
      desiredKeys: nil
    )

    operation.configurationsByRecordZoneID = [zoneIdentifier: config]

    operation.recordZoneIDs = [zoneIdentifier]
    operation.fetchAllChanges = true

    // Called if the record zone fetch was not fully completed
    operation.recordZoneChangeTokensUpdatedBlock = { [weak self] _, changeToken, _ in
      guard let self = self else { return }

      guard let changeToken = changeToken else { return }

      // The fetch may have failed halfway through, so we need to save the change token,
      // emit the current records, and then clear the arrays so we can re-request for the
      // rest of the data.
      self.workQueue.async {
        os_log("Commiting new change token and emitting changes", log: self.log, type: .debug)

        self.privateChangeToken = changeToken
        self.emitServerChanges(with: changedRecords, deletedRecordIDs: deletedRecordIDs)
        changedRecords = []
        deletedRecordIDs = []
      }
    }

    // Called after the record zone fetch completes
    operation.recordZoneFetchCompletionBlock = { [weak self] _, token, _, _, error in
      guard let self = self else { return }

      if let error = error as? CKError {
        os_log(
          "Failed to fetch record zone changes: %{public}@",
          log: self.log,
          type: .error,
          String(describing: error))

        if error.code == .changeTokenExpired {
          os_log(
            "Change token expired, resetting token and trying again", log: self.log, type: .error)

          self.workQueue.async {
            self.privateChangeToken = nil
            self.fetchRemoteChanges()
          }
        } else {
          error.retryCloudKitOperationIfPossible(self.log, queue: self.workQueue) {
            self.fetchRemoteChanges()
          }
        }
      } else {
        os_log("Commiting new change token", log: self.log, type: .debug)

        self.workQueue.async {
          self.privateChangeToken = token
        }
      }
    }

    operation.recordChangedBlock = { [weak self] record in
      self?.workQueue.async {
        changedRecords.append(record)
      }
    }

    operation.recordWithIDWasDeletedBlock = { [weak self] recordID, recordType in
      self?.workQueue.async {
        guard let engineRecordType = self?.recordType,
          engineRecordType == recordType
        else { return }
        deletedRecordIDs.append(recordID)
      }
    }

    operation.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
      guard let self = self else { return }

      if let error = error {
        os_log(
          "Failed to fetch record zone changes: %{public}@",
          log: self.log,
          type: .error,
          String(describing: error))

        error.retryCloudKitOperationIfPossible(self.log, queue: self.workQueue) {
          self.fetchRemoteChanges()
        }
      } else {
        os_log("Finished fetching record zone changes", log: self.log, type: .info)

        self.workQueue.async {
          self.emitServerChanges(with: changedRecords, deletedRecordIDs: deletedRecordIDs)
          changedRecords = []
          deletedRecordIDs = []
        }
      }
    }

    operation.qualityOfService = .userInitiated
    operation.database = privateDatabase

    cloudOperationQueue.addOperation(operation)
  }

  // MARK: - Private

  private var privateChangeToken: CKServerChangeToken? {
    get {
      guard let data = defaults.data(forKey: privateChangeTokenKey) else { return nil }
      guard !data.isEmpty else { return nil }

      do {
        let token = try NSKeyedUnarchiver.unarchivedObject(
          ofClass: CKServerChangeToken.self, from: data)

        return token
      } catch {
        os_log(
          "Failed to decode CKServerChangeToken from defaults key privateChangeToken", log: log,
          type: .error)
        return nil
      }
    }
    set {
      guard let newValue = newValue else {
        defaults.setValue(Data(), forKey: privateChangeTokenKey)
        return
      }

      do {
        let data = try NSKeyedArchiver.archivedData(
          withRootObject: newValue, requiringSecureCoding: true)

        defaults.set(data, forKey: privateChangeTokenKey)
      } catch {
        os_log(
          "Failed to encode private change token: %{public}@", log: self.log, type: .error,
          String(describing: error))
      }
    }
  }

  private func emitServerChanges(with changedRecords: [CKRecord], deletedRecordIDs: [CKRecord.ID]) {
    guard !changedRecords.isEmpty || !deletedRecordIDs.isEmpty else {
      os_log("Finished record zone changes fetch with no changes", log: log, type: .info)
      return
    }

    os_log(
      "Will emit %d changed record(s) and %d deleted record(s)", log: log, type: .info,
      changedRecords.count, deletedRecordIDs.count)

    let models: Set<Model> = Set(
      changedRecords.compactMap { record in
        do {
          let decoder = CKRecordDecoder()
          return try decoder.decode(Model.self, from: record)
        } catch {
          os_log(
            "Error decoding item from record: %{public}@", log: self.log, type: .error,
            String(describing: error))
          return nil
        }
      })

    let deletedIdentifiers = Set(deletedRecordIDs.map(\.recordName))

    modelsChangedSubject.send(.updated(models))
    modelsChangedSubject.send(.deleted(deletedIdentifiers))
  }
}
