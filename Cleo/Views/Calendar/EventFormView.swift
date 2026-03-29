import SwiftUI
import UIKit

// MARK: - Tappable Calendar Picker

private struct TappableCalendarPicker: UIViewRepresentable {
    @Binding var selectedDate: Date
    var minimumDate: Date?
    var onDateSelected: () -> Void

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar.current
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        selection.setSelected(comps, animated: false)
        view.selectionBehavior = selection
        if let min = minimumDate {
            view.availableDateRange = DateInterval(start: min, end: Date.distantFuture)
        }
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self
        if let min = minimumDate {
            uiView.availableDateRange = DateInterval(start: min, end: Date.distantFuture)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        var parent: TappableCalendarPicker
        init(parent: TappableCalendarPicker) { self.parent = parent }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            let cal = Calendar.current
            if let comps = dateComponents, let date = cal.date(from: comps) {
                var merged = cal.dateComponents([.year, .month, .day], from: date)
                let time = cal.dateComponents([.hour, .minute, .second], from: parent.selectedDate)
                merged.hour = time.hour
                merged.minute = time.minute
                merged.second = time.second
                if let finalDate = cal.date(from: merged) {
                    parent.selectedDate = finalDate
                }
            } else {
                let comps = cal.dateComponents([.year, .month, .day], from: parent.selectedDate)
                selection.setSelected(comps, animated: false)
            }
            DispatchQueue.main.async { self.parent.onDateSelected() }
        }
    }
}

// MARK: - Quarter Hour Time Picker

private struct QuarterHourTimePicker: UIViewRepresentable {
    @Binding var selectedDate: Date

    private static let hours = Array(1...12)
    private static let minutes = [0, 15, 30, 45]
    private static let periods = ["AM", "PM"]

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        context.coordinator.decompose(from: selectedDate, picker: picker)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: QuarterHourTimePicker
        private var hour12 = 9
        private var minuteIndex = 0
        private var periodIndex = 0

        init(parent: QuarterHourTimePicker) { self.parent = parent }

        func decompose(from date: Date, picker: UIPickerView) {
            let cal = Calendar.current
            let h24 = cal.component(.hour, from: date)
            let m = cal.component(.minute, from: date)

            let snapped = ((m + 7) / 15) * 15
            let adjustedMinute = snapped == 60 ? 0 : snapped
            let adjustedHour = snapped == 60 ? (h24 + 1) % 24 : h24

            periodIndex = adjustedHour >= 12 ? 1 : 0
            let h12 = adjustedHour % 12
            hour12 = h12 == 0 ? 12 : h12
            minuteIndex = QuarterHourTimePicker.minutes.firstIndex(of: adjustedMinute) ?? 0

            picker.selectRow(hour12 - 1, inComponent: 0, animated: false)
            picker.selectRow(minuteIndex, inComponent: 1, animated: false)
            picker.selectRow(periodIndex, inComponent: 2, animated: false)
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0: QuarterHourTimePicker.hours.count
            case 1: QuarterHourTimePicker.minutes.count
            case 2: QuarterHourTimePicker.periods.count
            default: 0
            }
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            switch component {
            case 0: "\(QuarterHourTimePicker.hours[row])"
            case 1: String(format: "%02d", QuarterHourTimePicker.minutes[row])
            case 2: QuarterHourTimePicker.periods[row]
            default: nil
            }
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            switch component {
            case 0: hour12 = QuarterHourTimePicker.hours[row]
            case 1: minuteIndex = row
            case 2: periodIndex = row
            default: break
            }
            recompose()
        }

        private func recompose() {
            let cal = Calendar.current
            var h24 = hour12 % 12
            if periodIndex == 1 { h24 += 12 }
            let minute = QuarterHourTimePicker.minutes[minuteIndex]

            var comps = cal.dateComponents([.year, .month, .day], from: parent.selectedDate)
            comps.hour = h24
            comps.minute = minute
            comps.second = 0
            if let newDate = cal.date(from: comps) {
                parent.selectedDate = newDate
            }
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat { 50 }
    }
}

// MARK: - Event Form View

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss

    let initialDate: Date
    let existingEvent: CalendarEvent?
    let claudeService: ClaudeAPIService?

    enum ItemType: Int, CaseIterable {
        case event = 0
        case todo = 1

        var label: String {
            switch self {
            case .event: "Event"
            case .todo: "To-Do"
            }
        }
    }

    let onSave: (String, Date, Date, Bool, String?, String?, Date?, Bool, Bool, String?) -> Void

    @State private var title = ""
    @State private var itemType: ItemType = .event
    @State private var todoEmoji = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var location = ""
    @State private var isAllDay = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedRecurrence: RecurrenceFrequency?
    @State private var hasRecurrenceEnd = false
    @State private var recurrenceEndDate = Date()
    @State private var reminderEnabled = false
    @State private var isSaving = false
    @State private var expandedPicker: String?
    @State private var naturalLanguageText = ""
    @State private var showFullForm = false
    @State private var isParsing = false
    @FocusState private var focusedField: FormField?

    private enum FormField { case title, location, nlp }
    private var isEditMode: Bool { existingEvent != nil }

    init(initialDate: Date, existingEvent: CalendarEvent? = nil, claudeService: ClaudeAPIService? = nil, onSave: @escaping (String, Date, Date, Bool, String?, String?, Date?, Bool, Bool, String?) -> Void) {
        self.initialDate = initialDate
        self.existingEvent = existingEvent
        self.claudeService = claudeService
        self.onSave = onSave

        if let event = existingEvent {
            _title = State(initialValue: event.wrappedTitle)
            if event.isTodo {
                _itemType = State(initialValue: .todo)
                _todoEmoji = State(initialValue: event.todoEmoji ?? "")
                let hasDue = event.todoHasDueDate
                _hasDueDate = State(initialValue: hasDue)
                _dueDate = State(initialValue: hasDue ? event.wrappedEndDate : Calendar.current.date(byAdding: .day, value: 7, to: event.wrappedStartDate) ?? event.wrappedStartDate)
            } else {
                _itemType = State(initialValue: .event)
            }
            _location = State(initialValue: event.location ?? "")
            _isAllDay = State(initialValue: event.isAllDay)
            _startDate = State(initialValue: event.wrappedStartDate)
            _endDate = State(initialValue: event.wrappedEndDate)
            _selectedRecurrence = State(initialValue: event.recurrence)
            _hasRecurrenceEnd = State(initialValue: event.recurrenceEndDate != nil)
            _recurrenceEndDate = State(initialValue: event.recurrenceEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: event.wrappedStartDate) ?? event.wrappedStartDate)
            _reminderEnabled = State(initialValue: event.reminderEnabled)
        } else {
            let cal = Calendar.current
            let dayStart = cal.startOfDay(for: initialDate)
            let nineAM = cal.date(byAdding: .hour, value: 9, to: dayStart) ?? initialDate
            _startDate = State(initialValue: nineAM)
            _endDate = State(initialValue: cal.startOfDay(for: initialDate))
            _recurrenceEndDate = State(initialValue: cal.date(byAdding: .month, value: 3, to: initialDate) ?? initialDate)
        }
    }

    private var showNLPMode: Bool {
        !isEditMode && !showFullForm && claudeService?.hasAPIKey == true
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                Form {
                    Section {
                        Picker("", selection: $itemType) {
                            ForEach(ItemType.allCases, id: \.rawValue) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    if showNLPMode {
                        naturalLanguageSection
                    } else {
                        fullFormSections
                    }
                }
                .onChange(of: expandedPicker) {
                    if let key = expandedPicker {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                scrollProxy.scrollTo("cal-\(key)", anchor: .center)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle({
                switch itemType {
                case .event: isEditMode ? "Edit Event" : "New Event"
                case .todo: isEditMode ? "Edit To-Do" : "New To-Do"
                }
            }())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if showNLPMode {
                        Button("Save") {
                            isSaving = true
                            Task {
                                await nlpSave()
                                isSaving = false
                                dismiss()
                            }
                        }
                        .disabled(naturalLanguageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    } else {
                        Button("Save") {
                            isSaving = true
                            directSave()
                            isSaving = false
                            dismiss()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                }
            }
            .onAppear {
                if showNLPMode {
                    focusedField = .nlp
                } else {
                    focusedField = .title
                }
            }
            .onChange(of: isAllDay) {
                expandedPicker = nil
                if isAllDay {
                    endDate = Calendar.current.startOfDay(for: startDate)
                    startDate = Calendar.current.startOfDay(for: startDate)
                }
            }
        }
    }

    // MARK: - NLP Section

    @ViewBuilder
    private var naturalLanguageSection: some View {
        Section {
            TextField(
                itemType == .todo ? "e.g. Book car service by next Friday" : "e.g. Dinner at Ormeggio Friday 7pm",
                text: $naturalLanguageText,
                axis: .vertical
            )
            .focused($focusedField, equals: .nlp)
            .lineLimit(1...3)
            .submitLabel(.done)

            Button {
                Task { await expandToFullForm() }
            } label: {
                HStack {
                    if isParsing {
                        ProgressView()
                            .controlSize(.small)
                        Text("Understanding...")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "slider.horizontal.3")
                        Text("Add more details")
                    }
                }
            }
            .disabled(isParsing)
        }
    }

    // MARK: - Full Form

    @ViewBuilder
    private var fullFormSections: some View {
        Section("Details") {
            TextField(itemType == .todo ? "What needs doing?" : "Event title", text: $title)
                .focused($focusedField, equals: .title)
            if itemType == .event {
                TextField("Location (optional)", text: $location)
                    .focused($focusedField, equals: .location)
            }
            if itemType == .todo {
                TextField("Emoji (optional)", text: $todoEmoji)
            }
        }

        if itemType == .todo {
            Section("Dates") {
                expandableDateRow("todoStart", label: "Start Date", date: startDate)
                if expandedPicker == "todoStart" {
                    TappableCalendarPicker(selectedDate: $startDate) {
                        withAnimation { expandedPicker = nil }
                    }
                    .id("cal-todoStart")
                }

                Toggle("Has Due Date", isOn: $hasDueDate)
                if hasDueDate {
                    expandableDateRow("todoDue", label: "Due Date", date: dueDate)
                    if expandedPicker == "todoDue" {
                        TappableCalendarPicker(selectedDate: $dueDate, minimumDate: startDate) {
                            withAnimation { expandedPicker = nil }
                        }
                        .id("cal-todoDue")
                    }
                }
            }

            Section("Reminder") {
                Toggle("Remind Me", isOn: $reminderEnabled)
                if reminderEnabled {
                    Text(hasDueDate ? "9 AM on the due date" : "9 AM on the start date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Section("Date & Time") {
                Toggle("All Day", isOn: $isAllDay)

                if isAllDay {
                    expandableDateRow("startDate", label: "Start Date", date: startDate)
                    if expandedPicker == "startDate" {
                        TappableCalendarPicker(selectedDate: $startDate) {
                            withAnimation { expandedPicker = nil }
                        }
                        .id("cal-startDate")
                    }
                    expandableDateRow("endDate", label: "End Date", date: endDate)
                    if expandedPicker == "endDate" {
                        TappableCalendarPicker(selectedDate: $endDate, minimumDate: startDate) {
                            withAnimation { expandedPicker = nil }
                        }
                        .id("cal-endDate")
                    }
                } else {
                    expandableDateRow("dateTime", label: "Date", date: startDate)
                    if expandedPicker == "dateTime" {
                        TappableCalendarPicker(selectedDate: $startDate) {
                            withAnimation { expandedPicker = nil }
                        }
                        .id("cal-dateTime")
                    }
                    QuarterHourTimePicker(selectedDate: $startDate)
                        .frame(height: 120)
                }
            }

            Section("Repeat") {
                Picker("Frequency", selection: $selectedRecurrence) {
                    Text("Never").tag(RecurrenceFrequency?.none)
                    ForEach(RecurrenceFrequency.allCases) { freq in
                        Text(freq.displayName).tag(Optional(freq))
                    }
                }

                if selectedRecurrence != nil {
                    Toggle("End Repeat", isOn: $hasRecurrenceEnd)
                    if hasRecurrenceEnd {
                        expandableDateRow("recEnd", label: "End Date", date: recurrenceEndDate)
                        if expandedPicker == "recEnd" {
                            TappableCalendarPicker(selectedDate: $recurrenceEndDate, minimumDate: startDate) {
                                withAnimation { expandedPicker = nil }
                            }
                            .id("cal-recEnd")
                        }
                    }
                }
            }

            Section("Reminder") {
                Toggle("Remind Me", isOn: $reminderEnabled)
                if reminderEnabled {
                    Text(isAllDay ? "9 AM on the day" : "15 min before")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Save

    private func directSave() {
        let effectiveEndDate: Date
        switch itemType {
        case .todo:
            effectiveEndDate = hasDueDate ? dueDate : startDate
        case .event:
            effectiveEndDate = isAllDay ? endDate : startDate
        }

        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = todoEmoji.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(
            title,
            startDate,
            effectiveEndDate,
            itemType == .event ? (isAllDay ? true : false) : false,
            itemType == .event ? (loc.isEmpty ? nil : loc) : nil,
            itemType == .todo ? nil : selectedRecurrence?.rawValue,
            itemType == .todo ? nil : (hasRecurrenceEnd ? recurrenceEndDate : nil),
            reminderEnabled,
            itemType == .todo,
            itemType == .todo ? (trimmedEmoji.isEmpty ? nil : trimmedEmoji) : nil
        )
    }

    private func nlpSave() async {
        let text = naturalLanguageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let parsed = await claudeService?.parseEventFromNaturalLanguage(text: text, referenceDate: Date()) {
            applyParsedInput(parsed)
        } else {
            title = text
        }

        directSave()
    }

    private func expandToFullForm() async {
        let text = naturalLanguageText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !text.isEmpty, let service = claudeService {
            isParsing = true
            if let parsed = await service.parseEventFromNaturalLanguage(text: text, referenceDate: Date()) {
                applyParsedInput(parsed)
            } else {
                title = text
            }
            isParsing = false
        }

        withAnimation { showFullForm = true }
        focusedField = .title
    }

    private func applyParsedInput(_ parsed: ParsedEventInput) {
        title = parsed.title
        isAllDay = parsed.isAllDay

        if let loc = parsed.location {
            location = loc
        }

        let cal = Calendar.current
        let baseDate = parsed.date ?? initialDate

        if let parsedTime = parsed.time {
            let timeComps = cal.dateComponents([.hour, .minute], from: parsedTime)
            var dateComps = cal.dateComponents([.year, .month, .day], from: baseDate)
            dateComps.hour = timeComps.hour
            dateComps.minute = timeComps.minute
            dateComps.second = 0
            startDate = cal.date(from: dateComps) ?? baseDate
        } else {
            if parsed.isAllDay {
                startDate = cal.startOfDay(for: baseDate)
            } else {
                let dayStart = cal.startOfDay(for: baseDate)
                startDate = cal.date(byAdding: .hour, value: 9, to: dayStart) ?? baseDate
            }
        }

        if let parsedEndDate = parsed.endDate {
            endDate = cal.startOfDay(for: parsedEndDate)
        } else {
            endDate = isAllDay ? cal.startOfDay(for: startDate) : startDate
        }
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func expandableDateRow(_ key: String, label: String, date: Date) -> some View {
        Button {
            focusedField = nil
            withAnimation {
                expandedPicker = expandedPicker == key ? nil : key
            }
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(Self.dateOnlyFormatter.string(from: date))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
