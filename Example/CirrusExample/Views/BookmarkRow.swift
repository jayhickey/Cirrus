import SwiftUI

struct BookmarkRow: View {
  @State var bookmark: Bookmark

  var body: some View {
    VStack(alignment: .leading) {

      Text("\(bookmark.url)")
        .font(.headline)

      Text(
        { () -> String in
          let formatter = DateFormatter()
          formatter.dateFormat = "MM/dd @ hh:mm:ss.SSS"
          formatter.locale = .autoupdatingCurrent
          formatter.timeZone = .autoupdatingCurrent
          return "Created on \(formatter.string(from: bookmark.created))"
        }()
      )
      .font(.subheadline)

      Text(bookmark.cloudKitIdentifier)
        .font(.caption)
        .scaledToFill()
    }
  }
}

struct BookmarkRow_Previews: PreviewProvider {
  static var previews: some View {
    BookmarkRow(
      bookmark: Bookmark(
        title: "Apple",
        url: testURLs.randomElement()!
      )
    )
  }
}
