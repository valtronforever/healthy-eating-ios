import SwiftUI

/// Open-source licenses: the app is MIT and uses only Apple frameworks.
struct LicensesView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Healthy Eating for iOS").font(.headline).foregroundStyle(.ink)
                    Text("MIT License. The source code and the license text are on GitHub.")
                        .foregroundStyle(.inkMuted)
                    if let url = URL(string: "https://github.com/valtronforever/healthy-eating-ios") {
                        Link("github.com/valtronforever/healthy-eating-ios", destination: url)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.accent)
                    }
                }
            } footer: {
                Text("The app contains no third-party code: it uses only Apple’s frameworks. Your server runs the open-source Healthy Eating backend, also MIT.")
                    .sectionTextStyle()
            }
            .listRowBackground(Color.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Open-source licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}
