import SwiftUI
import SwiftData

struct TriggerEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let sop: SOP
    @Query(sort: \SOP.name) private var allSOPs: [SOP]

    @State private var triggers: [Trigger] = []
    @State private var showingNewTrigger = false
    @State private var newTriggerKind: TriggerKind = .scheduled

    var body: some View {
        NavigationStack {
            List {
                if triggers.isEmpty {
                    Text("No triggers yet")
                        .foregroundStyle(.secondary)
                }

                ForEach(triggers) { trigger in
                    TriggerRow(trigger: trigger, allSOPs: eligibleSOPs)
                }
                .onDelete { indexSet in
                    deleteTriggers(at: indexSet)
                }

                Section {
                    Menu {
                        Button {
                            newTriggerKind = .scheduled
                            addTrigger(kind: .scheduled)
                        } label: {
                            Label("Scheduled", systemImage: "clock")
                        }
                        Button {
                            newTriggerKind = .chained
                            addTrigger(kind: .chained)
                        } label: {
                            Label("Chained", systemImage: "link")
                        }
                    } label: {
                        Label("Add Trigger", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Triggers")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndSchedule()
                        dismiss()
                    }
                }
            }
            .onAppear {
                triggers = sop.triggers
            }
        }
    }

    private var eligibleSOPs: [SOP] {
        allSOPs.filter { $0.id != sop.id && !$0.isChild && !$0.isOneShot }
    }

    private func addTrigger(kind: TriggerKind) {
        Task {
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                let trigger = Trigger(kind: kind, sop: sop)
                if kind == .scheduled {
                    trigger.recurrence = TriggerRecurrence.daily.rawValue
                    trigger.hour = 9
                    trigger.minute = 0
                }
                context.insert(trigger)
                triggers.append(trigger)
                try? context.save()
            }
        }
    }

    private func deleteTriggers(at indexSet: IndexSet) {
        for index in indexSet {
            let trigger = triggers[index]
            NotificationService.shared.cancelTrigger(trigger)
            context.delete(trigger)
        }
        triggers.remove(atOffsets: indexSet)
        try? context.save()
    }

    private func saveAndSchedule() {
        try? context.save()
        guard !NotificationService.shared.isPaused else { return }
        for trigger in triggers where trigger.isEnabled {
            if trigger.triggerKind == .scheduled {
                NotificationService.shared.scheduleTrigger(trigger, sopName: sop.name)
            }
        }
    }
}

// MARK: - Individual trigger row

struct TriggerRow: View {
    @Bindable var trigger: Trigger
    let allSOPs: [SOP]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: trigger.triggerKind == .scheduled ? "clock.fill" : "link")
                    .foregroundStyle(trigger.triggerKind == .scheduled ? .blue : .orange)
                Text(trigger.triggerKind == .scheduled ? "Scheduled" : "Chained")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $trigger.isEnabled)
                    .labelsHidden()
            }

            if trigger.triggerKind == .scheduled {
                ScheduledTriggerConfig(trigger: trigger)
            } else {
                ChainedTriggerConfig(trigger: trigger, allSOPs: allSOPs)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Scheduled trigger config

struct ScheduledTriggerConfig: View {
    @Bindable var trigger: Trigger

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Recurrence", selection: Binding(
                get: { trigger.triggerRecurrence },
                set: { trigger.recurrence = $0.rawValue }
            )) {
                Text("Once").tag(TriggerRecurrence.once)
                Text("Daily").tag(TriggerRecurrence.daily)
                Text("Weekly").tag(TriggerRecurrence.weekly)
                Text("Monthly").tag(TriggerRecurrence.monthly)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Time:")
                    .font(.subheadline)
                Picker("Hour", selection: Binding(
                    get: { trigger.hour ?? 9 },
                    set: { trigger.hour = $0 }
                )) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 60)
                Text(":")
                Picker("Minute", selection: Binding(
                    get: { trigger.minute ?? 0 },
                    set: { trigger.minute = $0 }
                )) {
                    ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 60)
            }

            if trigger.triggerRecurrence == .weekly {
                Picker("Day", selection: Binding(
                    get: { trigger.weekday ?? 2 },
                    set: { trigger.weekday = $0 }
                )) {
                    Text("Sun").tag(1)
                    Text("Mon").tag(2)
                    Text("Tue").tag(3)
                    Text("Wed").tag(4)
                    Text("Thu").tag(5)
                    Text("Fri").tag(6)
                    Text("Sat").tag(7)
                }
                .pickerStyle(.segmented)
            }

            if trigger.triggerRecurrence == .monthly {
                Picker("Day of month", selection: Binding(
                    get: { trigger.dayOfMonth ?? 1 },
                    set: { trigger.dayOfMonth = $0 }
                )) {
                    ForEach(1...28, id: \.self) { d in
                        Text("\(d)").tag(d)
                    }
                }
            }

            if trigger.triggerRecurrence == .once {
                DatePicker("Date", selection: Binding(
                    get: { trigger.scheduledDate ?? Date() },
                    set: { trigger.scheduledDate = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)
            }
        }
    }
}

// MARK: - Chained trigger config

struct ChainedTriggerConfig: View {
    @Bindable var trigger: Trigger
    let allSOPs: [SOP]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fire after completing:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Predecessor", selection: Binding(
                get: { trigger.predecessorSOPId },
                set: { trigger.predecessorSOPId = $0 }
            )) {
                Text("Select SOP...").tag(nil as UUID?)
                ForEach(allSOPs) { sop in
                    Text(sop.name).tag(sop.id as UUID?)
                }
            }
        }
    }
}
