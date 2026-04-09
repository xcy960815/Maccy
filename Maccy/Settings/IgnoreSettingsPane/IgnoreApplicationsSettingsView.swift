import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct IgnoreApplicationsSettingsView: View {
  @Default(.ignoredApps) private var ignoredApps

  @State private var isAdding = false
  @State private var selection = ""

  var body: some View {
    VStack(alignment: .leading) {
      if #available(macOS 13.0, *) {
        List(selection: $selection) {
          rows
        }
        .onDeleteCommand {
          remove(selection)
        }
      } else {
        List {
          rows
        }
        .onDeleteCommand {
          remove(selection)
        }
      }

      HStack {
        HStack(spacing: 8) {
          Button {
            isAdding = true
          } label: {
            Image(systemName: "plus")
          }

          Button {
            remove(selection)
          } label: {
            Image(systemName: "minus")
          }
        }
        .frame(width: 50)
        .fileImporter(
          isPresented: $isAdding,
          allowedContentTypes: [.applicationBundle]
        ) { result in
          switch result {
          case .success(let appUrl):
            if let bundle = Bundle(path: appUrl.path),
               let bundleIdentifier = bundle.bundleIdentifier,
               !ignoredApps.contains(bundleIdentifier) {
              ignoredApps.append(bundleIdentifier)
            }
          case .failure(let error):
            print("Failed to select application: \(error)")
          }
        }

        Defaults.Toggle(key: .ignoreAllAppsExceptListed) {
          Text("IgnoredAllAppsExceptListed", tableName: "IgnoreSettings")
        }
      }

      Text("IgnoredAppsDescription", tableName: "IgnoreSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }.padding()
  }

  private func remove(_ app: String?) {
    guard let app else { return }

    ignoredApps.removeAll(where: { $0 == app })
  }

  @ViewBuilder
  private var rows: some View {
    ForEach($ignoredApps) { $app in
      Group {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
          Label(
            title: {
              Text(NSWorkspace.shared.applicationName(url: url))
                .padding(.horizontal, 5)
            },
            icon: {
              Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            }
          )
        } else {
          Label(
            title: { Text(app).padding(.horizontal, 5) },
            icon: { Image(systemName: "questionmark.circle").imageScale(.large) }
          )
        }
      }
      .frame(height: 32)
      .padding(.horizontal, 5)
      .tag(app)
      .contentShape(Rectangle())
      .onTapGesture {
        selection = app
      }
    }
  }
}

private struct IgnoreApplicationsSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    IgnoreApplicationsSettingsView()
      .environment(\.locale, .init(identifier: "en"))
  }
}
