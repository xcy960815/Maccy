import SwiftUI

struct IgnoreSettingsPane: View {
  var body: some View {
    TabView {
      IgnoreApplicationsSettingsView()
        .tabItem {
          Text("ApplicationsTab", tableName: "IgnoreSettings")
        }
      IgnorePasteboardTypesSettingsView()
        .tabItem {
          Text("PasteboardTypesTab", tableName: "IgnoreSettings")
        }
      IgnoreRegexpsSettingsView()
        .tabItem {
          Text("RegexpTab", tableName: "IgnoreSettings")
        }
    }
    .frame(maxWidth: 500, minHeight: 400)
    .padding()
  }
}

private struct IgnoreSettingsPane_Previews: PreviewProvider {
  static var previews: some View {
    IgnoreSettingsPane()
      .environment(\.locale, .init(identifier: "en"))
  }
}
