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
      logHandler(
        "Already have custom zone, skipping creation but checking if zone really exists", .debug)

      checkCustomZone()

      return
    }

    logHandler("Creating CloudKit zone \(zoneIdentifier.zoneName)", .info)

    let zone = CKRecordZone(zoneID: zoneIdentifier)
    let operation = CKModifyRecordZonesOperation(
      recordZonesToSave: [zone],
      recordZoneIDsToDelete: nil
    )

    operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
      guard let self = self else { return }

      if let error = error {
        self.logHandler(
          "Failed to create custom CloudKit zone: \(String(describing: error))", .error)

        error.retryCloudKitOperationIfPossible(self.logHandler, queue: self.workQueue) {
          self.createCustomZoneIfNeeded()
        }
      } else {
        self.logHandler("Zone created successfully", .info)
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
        self.logHandler(
          "Failed to check for custom zone existence: \(String(describing: error))", .error)

        if !error.retryCloudKitOperationIfPossible(
          self.logHandler, queue: self.workQueue, with: { self.checkCustomZone() })
        {
          self.logHandler(
            "Irrecoverable error when fetching custom zone, assuming it doesn't exist: \(String(describing: error))",
            .error)

          self.workQueue.async {
            self.createdCustomZone = false
            self.createCustomZoneIfNeeded()
          }
        }
      } else if ids?.isEmpty ?? true {
        self.logHandler("Custom zone reported as existing, but it doesn't exist. Creating.", .error)
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
