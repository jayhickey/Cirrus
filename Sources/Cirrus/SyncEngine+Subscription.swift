import CloudKit
import Foundation
import os.log

extension SyncEngine {

  // MARK: - Internal

  func initializeSubscription(with queue: OperationQueue) -> Bool {
    self.createPrivateSubscriptionsIfNeeded()
    queue.waitUntilAllOperationsAreFinished()
    guard self.createdPrivateSubscription else { return false }
    return true
  }

  // MARK: - Private

  private var createdPrivateSubscription: Bool {
    get {
      return defaults.bool(forKey: createdPrivateSubscriptionKey)
    }
    set {
      defaults.set(newValue, forKey: createdPrivateSubscriptionKey)
    }
  }

  private func createPrivateSubscriptionsIfNeeded() {
    guard !createdPrivateSubscription else {
      os_log(
        "Already subscribed to private database changes, skipping subscription but checking if it really exists",
        log: log, type: .debug)

      checkSubscription()

      return
    }

    let subscription = CKRecordZoneSubscription(
      zoneID: zoneIdentifier, subscriptionID: privateSubscriptionIdentifier)

    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true

    subscription.notificationInfo = notificationInfo
    subscription.recordType = recordType

    let operation = CKModifySubscriptionsOperation(
      subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)

    operation.database = privateDatabase
    operation.qualityOfService = .userInitiated

    operation.modifySubscriptionsCompletionBlock = { [weak self] _, _, error in
      guard let self = self else { return }

      if let error = error {
        os_log(
          "Failed to create private CloudKit subscription: %{public}@",
          log: self.log,
          type: .error,
          String(describing: error))

        error.retryCloudKitOperationIfPossible(self.log, queue: self.workQueue) {
          self.createPrivateSubscriptionsIfNeeded()
        }
      } else {
        os_log("Private subscription created successfully", log: self.log, type: .info)
        self.createdPrivateSubscription = true
      }
    }

    cloudOperationQueue.addOperation(operation)
  }

  private func checkSubscription() {
    let operation = CKFetchSubscriptionsOperation(subscriptionIDs: [privateSubscriptionIdentifier])

    operation.fetchSubscriptionCompletionBlock = { [weak self] ids, error in
      guard let self = self else { return }

      if let error = error {
        os_log(
          "Failed to check for private zone subscription existence: %{public}@", log: self.log,
          type: .error, String(describing: error))

        if !error.retryCloudKitOperationIfPossible(
          self.log, queue: self.workQueue, with: { self.checkSubscription() })
        {
          os_log(
            "Irrecoverable error when fetching private zone subscription, assuming it doesn't exist: %{public}@",
            log: self.log, type: .error, String(describing: error))

          self.workQueue.async {
            self.createdPrivateSubscription = false
            self.createPrivateSubscriptionsIfNeeded()
          }
        }
      } else if ids?.isEmpty ?? true {
        os_log(
          "Private subscription reported as existing, but it doesn't exist. Creating.",
          log: self.log, type: .error
        )

        self.workQueue.async {
          self.createdPrivateSubscription = false
          self.createPrivateSubscriptionsIfNeeded()
        }
      } else {
        os_log(
          "Private subscription found, the device is subscribed to CloudKit change notifications.",
          log: self.log, type: .error
        )
      }
    }

    operation.qualityOfService = .userInitiated
    operation.database = privateDatabase

    cloudOperationQueue.addOperation(operation)
  }
}
