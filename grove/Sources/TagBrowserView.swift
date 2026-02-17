import SwiftUI
import SwiftData

struct TagBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var selectedItem: Item?

    @State private var selectedTag: Tag?
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .custom

    private var groupedTags: [(TagCategory, [Tag])] {
        let grouped = Dictionary(grouping: allTags, by: \.category)
        return TagCategory.allCases.compactMap { category in
            guard let tags = grouped[category], !tags.isEmpty else { return nil }
            return (category, tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    var body: some View {
        if let tag = selectedTag {
            TagDetailView(tag: tag, selectedItem: $selectedItem, onBack: { selectedTag = nil })
        } else {
            tagBrowserList
        }
    }

    private var tagBrowserList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tags")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(allTags.count) tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    isCreatingTag.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Tag")
            }
            .padding()

            Divider()

            if allTags.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // New tag creation inline
                        if isCreatingTag {
                            newTagForm
                        }

                        ForEach(groupedTags, id: \.0) { category, tags in
                            tagCategorySection(category: category, tags: tags)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Tags Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tags help organize your items. Add tags to items from the inspector, or create one here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if !isCreatingTag {
                Button("Create a Tag") {
                    isCreatingTag = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                newTagForm
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var newTagForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Tag")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Tag name", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { createTag() }

                Picker("", selection: $newTagCategory) {
                    ForEach(TagCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(cat)
                    }
                }
                .frame(width: 120)

                Button("Add") { createTag() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") {
                    newTagName = ""
                    isCreatingTag = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tagCategorySection(category: TagCategory, tags: [Tag]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)
                    .foregroundStyle(category.color)
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(tags.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    TagPillView(tag: tag) {
                        selectedTag = tag
                    }
                }
            }
        }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // Prevent duplicates (case-insensitive)
        if allTags.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            return
        }

        let tag = Tag(name: name, category: newTagCategory)
        modelContext.insert(tag)
        newTagName = ""
        isCreatingTag = false
    }
}

// MARK: - Tag Pill View (browsable, colored by category)

struct TagPillView: View {
    let tag: Tag
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tag.category.color)
                    .frame(width: 6, height: 6)
                Text(tag.name)
                    .font(.caption)
                if tag.items.count > 0 {
                    Text("\(tag.items.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tag.category.color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
