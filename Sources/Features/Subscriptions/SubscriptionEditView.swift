import SwiftData
import SwiftUI

// Define a subscription once; the app posts its expenses from then on.
struct SubscriptionEditView: View {
    let subscription: Subscription?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var name = ""
    @State private var amountText = ""
    @State private var currency = "ARS"
    @State private var cadence = "monthly"
    @State private var billingDay = 1
    @State private var billingMonth = 1
    @State private var isActive = true
    @State private var categoryId: UUID?
    @State private var confirmingDelete = false

    var body: some View {
        SheetScaffold(title: subscription == nil ? "New subscription" : "Edit subscription") {
            VStack(spacing: 22) {
                fields
                categoryPicker
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        } footer: {
            VStack(spacing: 12) {
                PrimaryButton(title: "Save", isEnabled: isValid, action: save)
                if subscription != nil {
                    Button("Delete subscription") { confirmingDelete = true }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.wRed)
                        .frame(height: 40)
                }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog(
            "Delete this subscription?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("Expenses it already posted stay where they are.")
        }
    }

    private var fields: some View {
        VStack(spacing: 0) {
            FormRow(label: "Name") {
                TextField("Netflix", text: $name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.wText)
                    .tint(.wAccent)
            }
            FormRow(label: "Amount") {
                HStack(spacing: 10) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(Color.wText)
                        .tint(.wAccent)
                    Picker("", selection: $currency) {
                        Text("AR$").tag("ARS")
                        Text("US$").tag("USD")
                    }
                    .pickerStyle(.menu)
                    .tint(.wAccentBright)
                }
            }
            FormRow(label: "Cadence") {
                Picker("", selection: $cadence) {
                    Text("Monthly").tag("monthly")
                    Text("Yearly").tag("yearly")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            if cadence == "yearly" {
                FormRow(label: "Month") {
                    Picker("", selection: $billingMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(DateFormatter().monthSymbols[month - 1]).tag(month)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.wAccentBright)
                }
            }
            FormRow(label: "Billing day") {
                Picker("", selection: $billingDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.menu)
                .tint(.wAccentBright)
            }
            FormRow(label: "Active", showsDivider: false) {
                Toggle("", isOn: $isActive)
                    .labelsHidden()
                    .tint(.wAccent)
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Category")
            FlowLayout(spacing: 9) {
                ForEach(categories) { category in
                    Text(category.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(categoryId == category.id ? Color.wText : Color.wTextSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(categoryId == category.id ? Color.wChipSelected : Color.wCardRaised, in: Capsule())
                        .overlay(Capsule().stroke(categoryId == category.id ? Color.wAccent : Color.wBorder, lineWidth: 1))
                        .onTapGesture { categoryId = category.id }
                }
            }
        }
    }

    private var amount: Decimal? {
        let normalized = amountText.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US")), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount != nil
    }

    private func load() {
        guard let subscription else { return }
        name = subscription.name
        amountText = Money.format(subscription.amount, currency: subscription.currency)
            .replacingOccurrences(of: "\(Money.symbol(for: subscription.currency)) ", with: "")
        currency = subscription.currency
        cadence = subscription.cadence
        billingDay = subscription.billingDay
        billingMonth = subscription.billingMonth ?? 1
        isActive = subscription.isActive
        categoryId = subscription.category?.id
    }

    private func save() {
        guard let amount else { return }
        let target = subscription ?? Subscription(name: name, amount: amount, currency: currency)
        target.name = name
        target.amount = amount
        target.currency = currency
        target.cadence = cadence
        target.billingDay = billingDay
        target.billingMonth = cadence == "yearly" ? billingMonth : nil
        target.isActive = isActive
        target.category = categories.first { $0.id == categoryId }
        if subscription == nil {
            // A new subscription starts posting from today, never backfilling
            // history the user never had in the app.
            target.lastPostedDate = Calendar.current.startOfDay(for: .now).addingTimeInterval(-1)
            context.insert(target)
        }
        try? context.save()
        SubscriptionPoster.postDue(in: context)
        dismiss()
    }

    private func delete() {
        guard let subscription else { return }
        context.delete(subscription)
        try? context.save()
        dismiss()
    }
}

private struct FormRow<Content: View>: View {
    let label: String
    var showsDivider = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wTextSecondary)
                Spacer()
                content()
                    .font(.system(size: 15))
            }
            .frame(minHeight: 52)
            if showsDivider { Divider().overlay(Color.wHairline) }
        }
    }
}
