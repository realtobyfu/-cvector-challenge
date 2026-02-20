import SwiftUI
import SwiftData

struct SearchOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @State private var viewModel: SearchViewModel?
    @State private var selectedIndex = 0
    @FocusState private var isQueryFieldFocused: Bool

    /// Optional board scope for board-context search
    var scopeBoard: Board?

    /// Called when a result is selected — navigates to item or board
    var onSelectItem: ((Item) -> Void)?
    var onSelectBoard: ((Board) -> Void)?
    var onSelectTag: ((Tag) -> Void)?

    private var flatResults: [SearchResult] {
        guard let vm = viewModel else { return [] }
        var flat: [SearchResult] = []
        for section in vm.orderedSections {
            if let sectionResults = vm.results[section] {
                flat.append(contentsOf: sectionResults)
            }
        }
        return flat
    }

    private var queryPlaceholder: String {
        if let scopeBoard {
            return "Search in \(scopeBoard.title)..."
        }
        return "Search Grove..."
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.groveItemTitle)
                    .foregroundStyle(Color.textSecondary)

                TextField(queryPlaceholder, text: queryBinding)
                    .textFieldStyle(.plain)
                    .font(.groveItemTitle)
                    .focused($isQueryFieldFocused)
                    .onSubmit {
                        viewModel?.flushPendingSearch()
                        selectCurrentResult()
                    }

                if let vm = viewModel, !vm.query.isEmpty {
                    Button {
                        vm.clearSearch()
                        selectedIndex = 0
                        isQueryFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isPresented = false
                } label: {
                    Text("esc")
                        .font(.groveShortcut)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentBadge)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider()

            // Results
            if let vm = viewModel, !vm.query.isEmpty {
                if vm.totalResultCount == 0 {
                    emptyState
                } else {
                    resultsList(vm: vm)
                }
            }
        }
        .frame(width: 600)
        .frame(maxHeight: 440)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderPrimary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .onAppear {
            let vm = SearchViewModel(modelContext: modelContext)
            vm.scopeBoard = scopeBoard
            viewModel = vm
            Task { @MainActor in
                await Task.yield()
                isQueryFieldFocused = true
            }
        }
        .onChange(of: flatResults.count) { _, newCount in
            if newCount == 0 {
                selectedIndex = 0
            } else if selectedIndex >= newCount {
                selectedIndex = max(0, newCount - 1)
            }
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < flatResults.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            viewModel?.flushPendingSearch()
            selectCurrentResult()
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel?.query ?? "" },
            set: { newValue in
                viewModel?.updateQuery(newValue)
                selectedIndex = 0
            }
        )
    }

    // MARK: - Results List

    private func resultsList(vm: SearchViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    var runningIndex = 0
                    ForEach(vm.orderedSections, id: \.self) { section in
                        if let sectionResults = vm.results[section] {
                            // Section header
                            HStack(spacing: 6) {
                                Image(systemName: section.iconName)
                                    .font(.groveMeta)
                                    .foregroundStyle(Color.textMuted)
                                Text(section.rawValue)
                                    .sectionHeaderStyle()
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                            ForEach(Array(sectionResults.enumerated()), id: \.element.id) { offset, result in
                                let globalIndex = runningIndex + offset
                                Button {
                                    selectedIndex = globalIndex
                                    navigateTo(result: result)
                                } label: {
                                    resultRow(result: result, isSelected: globalIndex == selectedIndex)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .id(globalIndex)
                            }

                            let _ = (runningIndex += sectionResults.count)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: selectedIndex) { _, newValue in
                proxy.scrollTo(newValue, anchor: .center)
            }
        }
    }

    private func resultRow(result: SearchResult, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            resultIcon(for: result)
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentBadge : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.groveBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.groveMeta)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Text("return")
                    .font(.groveBadge)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentBadge)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 6)
        .selectedItemStyle(isSelected)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func resultIcon(for result: SearchResult) -> some View {
        switch result.type {
        case .item:
            if let item = result.item {
                Image(systemName: item.type.iconName)
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Image(systemName: "doc")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            }
        case .reflection:
            Image(systemName: "text.alignleft")
                .font(.groveMeta)
                .foregroundStyle(Color.textSecondary)
        case .tag:
            if let tag = result.tag {
                Image(systemName: tag.category.iconName)
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Image(systemName: "tag")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            }
        case .board:
            if let board = result.board, let icon = board.icon {
                Image(systemName: icon)
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Image(systemName: "folder")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.groveTitleLarge)
                .foregroundStyle(Color.textTertiary)
            Text("No results found")
                .font(.groveBody)
                .foregroundStyle(Color.textSecondary)
            Text("Try a different search term")
                .font(.groveBodySmall)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Navigation

    private func selectCurrentResult() {
        let flat = flatResults
        guard selectedIndex >= 0 && selectedIndex < flat.count else { return }
        navigateTo(result: flat[selectedIndex])
    }

    private func navigateTo(result: SearchResult) {
        isPresented = false

        switch result.type {
        case .item:
            if let item = result.item {
                onSelectItem?(item)
            }
        case .reflection:
            // Navigate to the reflection's parent item
            if let item = result.item {
                onSelectItem?(item)
            }
        case .tag:
            if let tag = result.tag {
                onSelectTag?(tag)
            }
        case .board:
            if let board = result.board {
                onSelectBoard?(board)
            }
        }
    }
}
