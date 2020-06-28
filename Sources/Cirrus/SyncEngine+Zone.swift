import CloudKit
import Foundation
import os.log

extension SyncEngine {

  // MARK: - Internal

  func initializeZone(with queue: OperationQueue) -> Bool {
    self.createCustomZoneIfNeeded()
    queue.waitUntilAllOperationsAreFinished()
    guard self.createdCustomZone else { return false }
    return true
  }

  // MARK: - Private

  private var createdCustomZone: Bool {
    get {
      return defaults.bool(forKey: createdCustomZoneKey)
    }
    set {
      defaults.set(newValue, forKey: createdCustomZoneKey)
    }
  }

  private func createCustomZoneIfNeeded() {
    guard !createdCustomZone else {
      os_log(
        "Already have custom zone, skipping creation but checking if zone really exists", log: log,
        type: .debug)

      checkCustomZone()

      return
    }

    os_log("Creating CloudKit zone %@", log: log, type: .info, zoneIdentifier.zoneName)

    let zone = CKRecordZone(zoneID: zoneIdentifier)
    let operation = CKModifyRecordZonesOperation(
      recordZonesToSave: [zone],
      recordZoneIDsToDelete: nil
    )

    operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
      guard let self = self else { return }

      if let error = error {
        os_log(
          "Failed to create custom CloudKit zone: %{public}@",
          log: self.log,
          type: .error,
          String(describing: error))

        error.retryCloudKitOperationIfPossible(self.log, queue: self.workQueue) {
          self.createCustomZoneIfNeeded()
        }
      } else {
        os_log("Zone created successfully", log: self.log, type: .info)
        self.createdCustomZone = true
      }
    }

    operation.qualityOfService = .userInitiated
    operation.database = privateDatabase

    cloudOperationQueue.addOperation(operation)
  }

  private func checkCustomZone() {
    let operation = CKFetchRecordZonesOperation(recordZoneIDs: [zoneIdentifier])

    operation.fetchRecordZonesCompletionBlock = { [weak self] ids, error in
      guard let self = self else { return }

      if let error = error {
        os_log(
          "Failed to check for custom zone existence: %{public}@", log: self.log, type: .error,
          String(describing: error))

        if !error.retryCloudKitOperationIfPossible(
          self.log, queue: self.workQueue, with: { self.checkCustomZone() })
        {
          os_log(
            "Irrecoverable error when fetching custom zone, assuming it doesn't exist: %{public}@",
            log: self.log, type: .error, String(describing: error))

          self.workQueue.async {
            self.createdCustomZone = false
            self.createCustomZoneIfNeeded()
          }
        }
      } else if ids?.isEmpty ?? true {
        os_log(
          "Custom zone reported as existing, but it doesn't exist. Creating.", log: self.log,
          type: .error)
        self.workQueue.async {
          self.createdCustomZone = false
          self.createCustomZoneIfNeeded()
        }
      }
    }

    operation.qualityOfService = .userInitiated
    operation.database = privateDatabase

    cloudOperationQueue.addOperation(operation)
  }
}
