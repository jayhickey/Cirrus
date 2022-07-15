import CloudKit
import CloudKitCodable
import Combine
import Foundation
import os.log

public final class SyncEngine<Model: CloudKitCodable> {

  public enum ModelChange {
    case deleted(Set<CloudKitIdentifier>)
    case updated(Set<Model>)
  }

  // MARK: - Public Properties

  /// A publisher that sends a `ModelChange` when models are updated or deleted on iCloud. No thread guarantees.
  public private(set) lazy var modelsChanged = modelsChangedSubject.eraseToAnyPublisher()

  /// The current iCloud account status for the user.
  @Published public internal(set) var accountStatus: AccountStatus = .unknown {
    willSet {
      // Setup the environment and force a sync if the user account status changes to available while the app is running
      if accountStatus != .unknown,
        newValue == .available
      {
        setupCloudEnvironment()
      }
    }
  }

  // MARK: - Internal Properties

  lazy var privateSubscriptionIdentifier = "\(zoneIdentifier.zoneName).subscription"
  lazy var privateChangeTokenKey = "TOKEN-\(zoneIdentifier.zoneName)"
  lazy var createdPrivateSubscriptionKey = "CREATEDSUBDB-\(zoneIdentifier.zoneName))"
  lazy var createdCustomZoneKey = "CREATEDZONE-\(zoneIdentifier.zoneName))"

  lazy var workQueue = DispatchQueue(
    label: "SyncEngine.Work.\(zoneIdentifier.zoneName)",
    qos: .userInitiated
  )
  private lazy var cloudQueue = DispatchQueue(
    label: "SyncEngine.Cloud.\(zoneIdentifier.zoneName)",
    qos: .userInitiated
  )

  let defaults: UserDefaults
  let recordType: CKRecord.RecordType
  let zoneIdentifier: CKRecordZone.ID

  let container: CKContainer
  let logHandler: (String, OSLogType) -> Void

  lazy var privateDatabase: CKDatabase = container.privateCloudDatabase

  var cancellables = Set<AnyCancellable>()
  let modelsChangedSubject = PassthroughSubject<ModelChange, Never>()

  private lazy var uploadContext: UploadRecordContext<Model> = UploadRecordContext(
    defaults: defaults, zoneID: zoneIdentifier, logHandler: logHandler)
  private lazy var deleteContext: DeleteRecordContext<Model> = DeleteRecordContext(
    defaults: defaults, zoneID: zoneIdentifier, logHandler: logHandler)

  lazy var cloudOperationQueue: OperationQueue = {
    let queue = OperationQueue()

    queue.underlyingQueue = cloudQueue
    queue.name = "SyncEngine.Cloud.\(zoneIdentifier.zoneName))"

    return queue
  }()

  /// - Parameters:
  ///   - defaults: The `UserDefaults` used to store sync state information
  ///   - containerIdentifier: An optional bundle identifier of the app whose container you want to access. The bundle identifier must be in the app’s com.apple.developer.icloud-container-identifiers entitlement. If this value is nil, the default container object will be used.
  ///   - initialItems: An initial array of items to sync
  ///
  /// `initialItems` is used to perform a sync of any local models that don't yet exist in CloudKit. The engine uses the
  /// presence of data in `cloudKitSystemFields` to determine what models to upload. Alternatively, you can just call `upload(_:)` to sync initial items.
  public init(
    defaults: UserDefaults = .standard,
    containerIdentifier: String? = nil,
    initialItems: [Model] = [],
    logHandler: ((String, OSLogType) -> Void)? = nil
  ) {
    self.defaults = defaults
    self.recordType = String(describing: Model.self)
    let zoneIdent = CKRecordZone.ID(
      zoneName: self.recordType,
      ownerName: CKCurrentUserDefaultName
    )
    self.zoneIdentifier = zoneIdent
    if let containerIdentifier = containerIdentifier {
      self.container = CKContainer(identifier: containerIdentifier)
    } else {
      self.container = CKContainer.default()
    }

    self.logHandler =
      logHandler ?? { string, level in
        let logger = Logger.init(
          subsystem: "com.jayhickey.Cirrus.\(zoneIdent)",
          category: String(describing: SyncEngine.self)
        )
        logger.log(level: level, "\(string)")
      }

    // Add items that haven't been uploaded yet.
    self.uploadContext.buffer(initialItems.filter { $0.cloudKitSystemFields == nil })

    observeAccountStatus()
    setupCloudEnvironment()
  }

  // MARK: - Public Methods

  /// Upload models to CloudKit.
  public func upload(_ models: Model...) {
    upload(models)
  }

  /// Upload an array of models to CloudKit.
  public func upload(_ models: [Model]) {
    logHandler(#function, .debug)

    workQueue.async {
      self.uploadContext.buffer(models)
      self.modifyRecords(with: self.uploadContext)
    }
  }

  /// Delete models from CloudKit.
  public func delete(_ models: Model...) {
    delete(models)
  }

  /// Delete an array of models from CloudKit.
  public func delete(_ models: [Model]) {
    logHandler(#function, .debug)

    workQueue.async {
      // Remove any pending upload items that match the items we want to delete
      self.uploadContext.removeFromBuffer(models)

      self.deleteContext.buffer(models)
      self.modifyRecords(with: self.deleteContext)
    }
  }

  /// Forces a data synchronization with CloudKit.
  ///
  /// Use this method for force sync any data that may not have been able to upload
  /// to CloudKit automatically due to network conditions or other factors.
  ///
  /// This method performs the following actions (in this order):
  /// 1. Uploads any models that were passed to `upload(_:)` and were unable to be uploaded to CloudKit.
  /// 2. Deletes any models that were passed to `delete(_:)` and were unable to be deleted from CloudKit.
  /// 3. Fetches any new model changes from CloudKit.
  public func forceSync() {
    logHandler(#function, .debug)

    workQueue.async {
      self.performUpdate(with: self.uploadContext)
      self.performUpdate(with: self.deleteContext)
      self.fetchRemoteChanges()
    }
  }

  /// Processes remote change push notifications from CloudKit.
  ///
  /// To subscribe to automatic changes, register for CloudKit push notifications by calling `application.registerForRemoteNotifications()`
  /// in your AppDelegate's `application(_:didFinishLaunchingWithOptions:)`. Then, call this method in
  /// `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` to process remote changes from CloudKit.
  /// - Parameters:
  ///   - userInfo: A dictionary that contains information about the remove notification. Pass the `userInfo` dictionary from `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` here.
  /// - Returns: Whether or not this notification was processed by the sync engine.
  @discardableResult public func processRemoteChangeNotification(with userInfo: [AnyHashable: Any])
    -> Bool
  {
    logHandler(#function, .debug)

    guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
      logHandler("Not a CKNotification", .error)
      return false
    }

    guard notification.subscriptionID == privateSubscriptionIdentifier else {
      logHandler("Not our subscription ID", .error)
      return false
    }

    logHandler("Received remote CloudKit notification for user data", .debug)

    self.workQueue.async { [weak self] in
      self?.fetchRemoteChanges()
    }

    return true
  }

  // MARK: - Private Methods

  private func setupCloudEnvironment() {
    workQueue.async { [weak self] in
      guard let self = self else { return }

      // Initialize CloudKit with private custom zone, but bail early if we fail
      guard self.initializeZone(with: self.cloudOperationQueue) else {
        self.logHandler("Unable to initialize zone, bailing from setup early", .error)
        return
      }

      // Subscribe to CloudKit changes, but bail early if we fail
      guard self.initializeSubscription(with: self.cloudOperationQueue) else {
        self.logHandler(
          "Unable to initialize subscription to changes, bailing from setup early", .error)
        return
      }
      self.logHandler("Cloud environment preparation done", .debug)

      self.performUpdate(with: self.uploadContext)
      self.performUpdate(with: self.deleteContext)
      self.fetchRemoteChanges()
    }
  }
}
