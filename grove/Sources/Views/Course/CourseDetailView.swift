import SwiftUI
import SwiftData

struct CourseDetailView: View {
    @Bindable var course: Course
    @Binding var selectedItem: Item?
    @Binding var openedItem: Item?
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [Item]
    @State private var showAddLectureSheet = false
    @State private var showEditCourseSheet = false

    /// Non-lecture items that share tags with a given lecture.
    private func supplementaryItems(for lecture: Item) -> [Item] {
        let lectureTagIDs = Set(lecture.tags.map(\.id))
        guard !lectureTagIDs.isEmpty else { return [] }
        return allItems.filter { item in
            item.id != lecture.id &&
            item.type != .courseLecture &&
            item.tags.contains(where: { lectureTagIDs.contains($0.id) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            courseHeader
            Divider()
            lectureList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(course.title)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showAddLectureSheet = true
                } label: {
                    Label("Add Lecture", systemImage: "plus")
                }
                .help("Add a lecture to this course")

                Button {
                    showEditCourseSheet = true
                } label: {
                    Label("Edit Course", systemImage: "pencil")
                }
                .help("Edit course details")
            }
        }
        .sheet(isPresented: $showAddLectureSheet) {
            AddLectureSheet(course: course)
        }
        .sheet(isPresented: $showEditCourseSheet) {
            CourseEditorSheet(course: course)
        }
    }

    // MARK: - Header

    private var courseHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap.fill")
                    .font(.groveTitleLarge)
                    .foregroundStyle(Color.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(.groveTitleLarge)
                        .fontWeight(.bold)

                    if let desc = course.courseDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.groveBodySecondary)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Progress indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(course.completedCount) / \(course.totalCount)")
                        .font(.groveItemTitle)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("lectures completed")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Progress bar
            ProgressView(value: course.progress)
                .tint(Color.textPrimary)

            // Source URL
            if let url = course.sourceURL, !url.isEmpty {
                Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.groveMeta)
                        Text(url)
                            .font(.groveMeta)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Lecture List

    private var lectureList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if course.orderedLectures.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(course.orderedLectures.enumerated()), id: \.element.id) { index, lecture in
                        lectureRow(lecture: lecture, index: index + 1)
                        if index < course.orderedLectures.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.system(size: 36))
                .foregroundStyle(Color.textSecondary)
            Text("No lectures yet")
                .font(.groveItemTitle)
            Text("Add lectures to track your progress through this course.")
                .font(.groveBodySecondary)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Lecture Row

    private func lectureRow(lecture: Item, index: Int) -> some View {
        let isCompleted = lecture.metadata["completed"] == "true"
        let supplements = supplementaryItems(for: lecture)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Completion checkbox
                Button {
                    toggleCompletion(lecture)
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.groveItemTitle)
                        .foregroundStyle(isCompleted ? Color.textPrimary : Color.textSecondary)
                }
                .buttonStyle(.plain)

                // Lecture number
                Text("\(index)")
                    .font(.groveMeta)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 24)

                // Lecture info
                VStack(alignment: .leading, spacing: 2) {
                    Text(lecture.title)
                        .font(.groveBody)
                        .fontWeight(.medium)
                        .strikethrough(isCompleted, color: Color.textSecondary)
                        .foregroundStyle(isCompleted ? Color.textSecondary : Color.textPrimary)

                    if let url = lecture.sourceURL, !url.isEmpty {
                        Text(url)
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                // Connection/reflection badges
                let connectionCount = lecture.outgoingConnections.count + lecture.incomingConnections.count
                if connectionCount > 0 {
                    Label("\(connectionCount)", systemImage: "link")
                        .font(.groveMeta)
                        .foregroundStyle(Color.textSecondary)
                }

                let reflectionCount = lecture.reflections.count
                if reflectionCount > 0 {
                    Label("\(reflectionCount)", systemImage: "text.alignleft")
                        .font(.groveMeta)
                        .foregroundStyle(Color.textSecondary)
                }

                // Open button
                Button {
                    selectedItem = lecture
                    openedItem = lecture
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedItem = lecture
            }
            .background(selectedItem?.id == lecture.id ? Color.accentBadge : Color.clear)

            // Supplementary materials
            if !supplements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related materials")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.leading, 48)

                    ForEach(supplements) { supplementItem in
                        HStack(spacing: 6) {
                            Image(systemName: supplementItem.type.iconName)
                                .font(.groveBadge)
                                .foregroundStyle(Color.textSecondary)
                            Text(supplementItem.title)
                                .font(.groveBodySmall)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.leading, 48)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = supplementItem
                            openedItem = supplementItem
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Actions

    private func toggleCompletion(_ lecture: Item) {
        if lecture.metadata["completed"] == "true" {
            lecture.metadata["completed"] = "false"
        } else {
            lecture.metadata["completed"] = "true"
        }
        lecture.updatedAt = .now
        course.updatedAt = .now
        try? modelContext.save()
    }
}

// MARK: - Add Lecture Sheet

struct AddLectureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let course: Course

    @State private var title = ""
    @State private var sourceURL = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Lecture")
                    .font(.groveItemTitle)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section("Lecture Title") {
                    TextField("e.g., Lecture 5: Fault Tolerance", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Source URL (optional)") {
                    TextField("https://...", text: $sourceURL)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    addLecture()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 280)
    }

    private func addLecture() {
        let lectureTitle = title.trimmingCharacters(in: .whitespaces)
        guard !lectureTitle.isEmpty else { return }

        let lecture = Item(title: lectureTitle, type: .courseLecture)
        lecture.status = .active
        if !sourceURL.trimmingCharacters(in: .whitespaces).isEmpty {
            lecture.sourceURL = sourceURL.trimmingCharacters(in: .whitespaces)
        }
        lecture.metadata["courseID"] = course.id.uuidString
        lecture.metadata["completed"] = "false"

        modelContext.insert(lecture)
        course.lectures.append(lecture)
        course.lectureOrder.append(lecture.id)
        course.updatedAt = .now
        try? modelContext.save()

        dismiss()
    }
}

// MARK: - Course Editor Sheet

struct CourseEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var course: Course

    @State private var title: String
    @State private var sourceURL: String
    @State private var description: String

    init(course: Course) {
        self.course = course
        _title = State(initialValue: course.title)
        _sourceURL = State(initialValue: course.sourceURL ?? "")
        _description = State(initialValue: course.courseDescription ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Course")
                    .font(.groveItemTitle)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section("Title") {
                    TextField("Course title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Description") {
                    TextField("Optional description", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Source URL") {
                    TextField("https://...", text: $sourceURL)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 340)
    }

    private func save() {
        course.title = title.trimmingCharacters(in: .whitespaces)
        course.sourceURL = sourceURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sourceURL.trimmingCharacters(in: .whitespaces)
        course.courseDescription = description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces)
        course.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
