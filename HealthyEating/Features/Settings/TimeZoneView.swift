import SwiftUI

/// The server's time zone for the person's local days. Defaults to the device (sent once when
/// the server has none); choosing another one is for people whose days follow a different place.
struct TimeZoneView: View {
    let current: String?
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    static func label(for identifier: String?) -> String {
        guard let identifier, let zone = TimeZone(identifier: identifier) else { return String(localized: "Not set") }
        return zone.localizedName(for: .generic, locale: .current) ?? identifier
    }

    var body: some View {
        let device = TimeZone.current.identifier
        List {
            if current != device {
                Section {
                    Button {
                        onSelect(device)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use this iPhone’s time zone").foregroundStyle(.accent)
                            Text(verbatim: Self.label(for: device)).font(.subheadline).foregroundStyle(.inkMuted)
                        }
                    }
                } footer: {
                    Text("Days on your server are counted in this time zone.").sectionTextStyle()
                }
                .listRowBackground(Color.surface)
            }
            Section {
                ForEach(results, id: \.self) { identifier in
                    Button {
                        onSelect(identifier)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: identifier.replacingOccurrences(of: "_", with: " ")).foregroundStyle(.ink)
                                Text(verbatim: Self.label(for: identifier)).font(.footnote).foregroundStyle(.inkMuted)
                            }
                            Spacer()
                            if identifier == current {
                                Image(systemName: "checkmark").foregroundStyle(.accent).accessibilityLabel(Text("Selected"))
                            }
                        }
                    }
                }
            }
            .listRowBackground(Color.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .searchable(text: $search, prompt: Text("City or region"))
        .navigationTitle("Time zone")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var results: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.localizedCaseInsensitiveContains(search.replacingOccurrences(of: " ", with: "_"))
                || Self.label(for: $0).localizedCaseInsensitiveContains(search)
        }
    }
}
