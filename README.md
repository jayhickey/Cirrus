# ☁️ Cirrus

[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](#installation)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](#license)
[![CI](https://github.com/jayhickey/Cirrus/workflows/CI/badge.svg)](https://github.com/jayhickey/Cirrus/actions?query=workflow%3ACI)

Cirrus provides simple [CloudKit](https://developer.apple.com/documentation/cloudkit) sync for [`Codable`](https://developer.apple.com/documentation/swift/codable) Swift models. Rather than support every CloudKit feature, Cirrus is opinionated and prioritizes simplicity, reliability, and ergonomics with Swift value types.

|         | Main Features  |
----------|-----------------
&#128581; | No more dealing with `CKRecord`, `CKOperation`, or `CKSubscription`
&#128064; | Observe models and iCloud account changes with [Combine](https://developer.apple.com/documentation/combine)
&#128242; | Automatic CloudKit push notification subscriptions
&#128640; | Clean architecture with concise but powerful API
&#127873; | Self-contained, no external dependencies

## Usage

After [installing](#installation) and following Apple's steps for [Enabling CloudKit in Your App](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/EnablingiCloudandConfiguringCloudKit/EnablingiCloudandConfiguringCloudKit.html):

1. Register your app for remote CloudKit push notifications

```swift
// AppDelegate.swift
func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  ...
  application.registerForRemoteNotifications()
  ...
}
```

2. Conform your model(s) to `CloudKitCodable`

```swift
import CloudKitCodable

struct Landmark: CloudKitCodable {
  struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
  }

  let identifier: UUID
  let name: String
  let coordinate: Coordinate

  // MARK: - CloudKitCodable

  /// A key that uniquely identifies the model. Use this identifier to update your 
  /// associated local models when the sync engine emits changes.
  var cloudKitIdentifier: CloudKitIdentifier {
    return identifier.uuidString
  }

  /// Managed by the sync engine, this should be set to nil when creating a new model.
  /// Be sure to save this when persisting models locally.
  var cloudKitSystemFields: Data? = nil

  /// Describes how to handle conflicts between client and server models.
  public static func resolveConflict(clientModel: Self, serverModel: Self) -> Self? {

    // Use `cloudKitLastModifiedDate` to check when models were last saved to the server
    guard let clientDate = clientModel.cloudKitLastModifiedDate,
      let serverDate = serverModel.cloudKitLastModifiedDate else {
      return clientModel
    }
    return clientDate > serverDate ? clientModel : serverModel
  }
}
```

3. Initialize a `SyncEngine` for the model

```swift
import Cirrus

let syncEngine = SyncEngine<Landmark>()
```

4. Configure the `SyncEngine` to process remote changes

```swift
// AppDelegate.swift
func application(
  _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) {
  syncEngine.processRemoteChangeNotification(with: userInfo)
  ...
}
```

5. Start syncing

```swift
// Upload new or updated models
syncEngine.upload(newLandmarks)

// Delete models
syncEngine.delete(oldLandmark)

// Observe remote model changes
syncEngine.modelsChanged
  .sink { change in
    // Update local models
    switch change {
    case let .updated(models):
      ...
    case let .deleted(modelIDs):
      ...
    }
  }

// Observe iCloud account status changes
syncEngine.$accountStatus
  .sink { accountStatus in
    switch accountStatus {
      case .available:
        ...
      case .noAccount:
        ...
      ...
    }
  }
```

And that's it! Cirrus supports syncing multiple model types too, just initialize and configure a new `SyncEngine` for every type you want to sync.

To see an example of how Cirrus can be integrated into an app, clone this repository and open the [CirrusExample](https://github.com/jayhickey/Cirrus/tree/main/Example) Xcode project.

## Installation

You can add Cirrus to an Xcode project by adding it as a package dependency.

  1. From the **File** menu, select **Swift Packages › Add Package Dependency…**
  2. Enter "https://github.com/jayhickey/cirrus" into the package repository URL text field
  3. Depending on how your project is structured:
      - If you have a single application target that needs access to the library, add both **Cirrus** and **CloudKitCodable** directly to your application.
      - If you have multiple targets where your models are in one target but you would like to handle syncing with Cirrus in another, then add **CloudKitCodable** to your model target and **Cirrus** to your syncing target.

## Limitations

Cirrus only supports private iCloud databases. If you need to store data in a public iCloud database, Cirrus is not the right tool for you.

Nested `Codable` types on `CloudKitCodable` models will _not_ be stored as separate `CKRecord` references; they are saved as `Data` blobs on the top level `CKRecord`. This leads to two important caveats:

1. `CKRecord` has a [1 MB data limit](https://developer.apple.com/documentation/cloudkit/ckrecord), so large models may not fit within a single record. The `SyncEngine` will not attempt to sync any models that are larger than 1 MB. If you are hitting this limitation, consider normalizing your data by creating discrete `CloudKitCodable` models that have identifier references to each other. You can use multiple `SyncEngine`s to sync each model type.
2. If any child models have properties that reference on-disk file URLs, they will not be converted into `CKAsset`s and stored in CloudKit. If you have a need to store files that are referenced by local file URLs on child models, you can override the `Encodable` `encode(to:)` and `Decodable` `init(from:)` methods on your model to set the file URLs as keys on the coding container of the top level `CloudKitCodable` type. The `SyncEngine` will then be able to sync your files to iCloud.

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.

## 🙌 Special Thanks

Thanks to [Tim Bueno](https://github.com/timbueno) for helping to build Cirrus.
