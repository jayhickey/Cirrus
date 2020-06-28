import SwiftUI
import UIKit

var syncManager: AppSyncManager?

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {

    let store = defaultStore()
    let sync = AppSyncManager(initialItems: store.value.bookmarks, dispatch: store.dispatch)
    syncManager = sync

    let contentView = ContentView(store: store)
      .environmentObject(sync)

    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(rootView: contentView)
      self.window = window
      window.makeKeyAndVisible()
    }
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    syncManager?.engine.forceSync()
  }
}
