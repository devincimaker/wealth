import SwiftData
import SwiftUI

// Base currency, read-only rate status, categories, iCloud state.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RateStore.self) private var rates
    @AppStorage("baseCurrency") private var baseCurrency = Money.defaultBaseCurrency
    @Query private var categories: [Category]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wSheet.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        currencySection
                        organizeSection
                        dataSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Text("WEALTH 0.1")
                        .font(.system(size: 11, design: .monospaced))
                        .kerning(0.9)
                        .foregroundStyle(Color.wTextTertiary.opacity(0.6))
                        .padding(.top, 36)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(.wAccentBright)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currencySection: some View {
        SettingsSection(title: "Currency", footer: "Rates refresh automatically on launch. Totals always convert at today's rate.") {
            SettingsRow(label: "Base currency") {
                Picker("", selection: $baseCurrency) {
                    Text("US Dollar").tag("USD")
                    Text("Argentine Peso").tag("ARS")
                }
                .pickerStyle(.menu)
                .tint(.wTextSecondary)
            }
            Divider().overlay(Color.wHairline).padding(.horizontal, 18)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Dólar blue")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.wText)
                    Spacer()
                    Text(blueRateText)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.wText)
                }
                Label(rates.statusLine, systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
        }
    }

    private var organizeSection: some View {
        SettingsSection(title: "Organize") {
            NavigationLink {
                CategoriesView()
            } label: {
                SettingsRow(label: "Categories") {
                    HStack(spacing: 8) {
                        Text("\(categories.count)")
                            .foregroundStyle(Color.wTextSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.wTextTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSection: some View {
        SettingsSection(title: "Data", footer: "Everything lives on this phone and in your private iCloud. Nowhere else.") {
            SettingsRow(label: "iCloud sync") {
                // TODO(cloudkit): report real sync state once the container is live.
                Label("Off for now", systemImage: "icloud.slash")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.wTextSecondary)
            }
        }
    }

    private var blueRateText: String {
        guard let rate = rates.rates["ARS"] else { return "Not fetched yet" }
        return "\(Money.formatRounded(rate, currency: "ARS")) / US$"
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title)
                .padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .background(Color.wCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.wHairline, lineWidth: 1))
            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.wTextTertiary)
                    .padding(.horizontal, 6)
            }
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.wText)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .contentShape(.rect)
    }
}
