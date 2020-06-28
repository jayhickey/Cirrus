import Cirrus
import CryptoKit
import SwiftUI

struct SyncEngineKey: EnvironmentKey {
  static let defaultValue: AppSyncManager = AppSyncManager(initialItems: [], dispatch: { _ in })
}

struct ContentView: View {
  @ObservedObject var store: Store
  @State var accountStatus: AccountStatus = .unknown
  @State private var selections: Set<Bookmark> = []
  @EnvironmentObject var syncManager: AppSyncManager

  var body: some View {
    NavigationView {
      VStack {
        VStack(alignment: .leading) {
          Text("iCloud Account Status: \(syncManager.accountStatus.stringValue)")
          Text("Hash: \(hash)")
          HStack {
            Text("Total Count: \(store.value.bookmarks.count)")
            if selections.count > 0 {
              Text("Selected: \(selections.count)")
            }
          }
        }
        .padding([.leading], 20)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.gray)
        List {
          ForEach(store.value.bookmarks.sorted(by: { $0.created > $1.created }), id: \.self) {
            bookmark in
            MultipleSelectionRow(
              childView: BookmarkRow(bookmark: bookmark),
              isSelected: self.selections.contains(bookmark)
            ) {
              if self.selections.contains(bookmark) {
                self.selections.remove(bookmark)
              } else {
                self.selections.insert(bookmark)
              }
            }
          }
        }

        Button("Add Bookmark") {
          if let element = testURLs.randomElement() {
            self.addBookmark(element)
          }
        }.padding()
      }
      .navigationBarTitle(Text("Bookmarks"))
      .navigationBarItems(
        leading: leadingNavigationItems(),
        trailing: trailingNavigationItems()
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }

  public var hash: String {
    do {
      var bookmarksCopy = store.value.bookmarks.sorted(by: { $0.created > $1.created })
      for (idx, val) in bookmarksCopy.enumerated() {
        var copy = val
        copy.cloudKitSystemFields = nil
        bookmarksCopy[idx] = copy
      }
      let data = try JSONEncoder().encode(bookmarksCopy)
      return Insecure.MD5.hash(data: data)
        .map {
          String(format: "%02hhx", $0)
        }.joined()
    } catch {
      return "Unknown"
    }
  }

  func leadingNavigationItems() -> some View {
    !selections.isEmpty
      ? Button(action: {
        let selections = self.selections
        self.modify(bookmarks: selections)
      }) {
        Text("Modify")
      }
      : Button(action: {
        self.store.dispatch(.fetchCloudChanges)
      }) {
        Text("Force Sync")
      }
  }

  func trailingNavigationItems() -> some View {
    !selections.isEmpty
      ? Button(action: {
        self.delete(bookmarks: self.selections)
      }) {
        Text("Delete")
      }
      : nil
  }

  func delete(bookmarks: Set<Bookmark>) {
    self.selections = []
    store.dispatch(.removeBookmarks(bookmarks))
  }

  func modify(bookmarks: Set<Bookmark>) {
    self.selections = []
    store.dispatch(.modifyBookmarks(bookmarks))
  }

  func addBookmark(_ url: URL) {
    store.dispatch(.addBookmark(url))
  }
}

extension AccountStatus {
  var stringValue: String {
    switch self {
    case .available:
      return "Available"
    case .couldNotDetermine:
      return "Could not determine"
    case .noAccount:
      return "No account"
    case .restricted:
      return "Restricted"
    case .unknown:
      return "Unknown"
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static let store = Store(
    value: AppState(
      bookmarks: [
        Bookmark(
          title: "Apple",
          url: URL(string: "https://apple.com")!
        )
      ]
    ),
    reducer: appReducer
  )
  static var previews: some View {
    ContentView(store: store)
  }
}
