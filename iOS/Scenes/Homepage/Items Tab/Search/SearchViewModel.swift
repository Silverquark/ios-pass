//
// SearchViewModel.swift
// Proton Pass - Created on 13/03/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Client
import Combine
import Core
import CryptoKit
import Entities
import Factory
import Macro
import Screens
import SwiftUI

enum SearchViewState {
    /// Indexing items
    case initializing
    /// No history, empty search query
    case empty
    /// Non-empty history
    case history([SearchEntryUiModel])
    /// No results for the given search query
    case noResults(String)
    /// Results with a given search query
    case results(ItemCount, any SearchResults)
    /// Error
    case error(any Error)
}

@MainActor
final class SearchViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    @Published private(set) var state = SearchViewState.initializing
    @Published var selectedType: ItemContentType?
    @Published var query = ""

    @AppStorage(Constants.sortTypeKey, store: kSharedUserDefaults)
    var selectedSortType = SortType.mostRecent { didSet { filterAndSortResults() } }

    // Injected properties
    private let itemRepository = resolve(\SharedRepositoryContainer.itemRepository)
    private let searchEntryDatasource = resolve(\SharedRepositoryContainer.localSearchEntryDatasource)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let getSearchableItems = resolve(\UseCasesContainer.getSearchableItems)
    private let getUserPreferences = resolve(\SharedUseCasesContainer.getUserPreferences)
    @LazyInjected(\SharedServiceContainer.userManager) private var userManager
    @LazyInjected(\SharedUseCasesContainer.addTelemetryEvent) private var addTelemetryEvent

    private(set) var searchMode: SearchMode
    let itemContextMenuHandler = resolve(\SharedServiceContainer.itemContextMenuHandler)

    private var lastSearchQuery = ""
    private var lastTask: Task<Void, Never>?
    private var filteringTask: Task<Void, Never>?
    private var searchableItems = [SearchableItem]()
    private var history = [SearchEntryUiModel]()
    private var results = [ItemSearchResult]()
    private var cancellables = Set<AnyCancellable>()

    var searchBarPlaceholder: String {
        searchMode.searchBarPlacehoder
    }

    var isTrash: Bool {
        searchMode.vaultSelection == .trash
    }

    init(searchMode: SearchMode) {
        self.searchMode = searchMode
        setup()
    }
}

// MARK: - Private APIs

private extension SearchViewModel {
    func indexItems() async {
        do {
            if case .error = state {
                state = .initializing
            }
            let userId = try await userManager.getActiveUserId()
            searchableItems = try await getSearchableItems(userId: userId, for: searchMode)
            try await refreshSearchHistory()
        } catch {
            state = .error(error)
        }
    }

    func refreshSearchHistory() async throws {
        guard let vaultSelection = searchMode.vaultSelection else {
            return
        }

        let searchEntries: [SearchEntry]
        if case let .precise(vault) = vaultSelection {
            searchEntries = try await searchEntryDatasource.getAllEntries(shareId: vault.shareId)
        } else {
            let userId = try await userManager.getActiveUserId()
            searchEntries = try await searchEntryDatasource.getAllEntries(userId: userId)
        }

        history = searchEntries.compactMap { entry in
            guard let item = searchableItems.first(where: {
                $0.shareId == entry.shareID && $0.itemId == entry.itemID
            }) else {
                return nil
            }
            return item.toSearchEntryUiModel
        }

        switch state {
        case .history:
            if history.isEmpty {
                state = .empty
            } else {
                state = .history(history)
            }
        default:
            break
        }
    }

    func doSearch(query: String) {
        lastSearchQuery = query
        switch searchMode {
        case .pinned:
            if query.isEmpty {
                results = searchableItems.toItemSearchResults
                filterAndSortResults()
                return
            }
        case .all:
            guard !query.isEmpty else {
                if history.isEmpty {
                    state = .empty
                } else {
                    state = .history(history)
                }
                return
            }
        }
        lastTask?.cancel()
        lastTask = Task { [weak self] in
            guard let self else {
                return
            }
            let hashedQuery = query.sha256
            logger.trace("Searching for \"\(hashedQuery)\"")
            if Task.isCancelled {
                return
            }
            results = searchableItems.result(for: query)
            if Task.isCancelled {
                return
            }
            filterAndSortResults()
            logger.trace("Get \(results.count) result(s) for \"\(hashedQuery)\"")
        }
    }

    func filterAndSortResults() {
        guard !results.isEmpty else {
            state = .noResults(lastSearchQuery)
            return
        }

        let filteredResults: [ItemSearchResult] = if let selectedType {
            results.filter { $0.type == selectedType }
        } else {
            results
        }
        filteringTask?.cancel()
        filteringTask = Task { [weak self] in
            guard let self else {
                return
            }
            if Task.isCancelled {
                return
            }
            let filteredAndSortedResults = await sortItems(for: filteredResults)
            if Task.isCancelled {
                return
            }
            state = .results(ItemCount(items: results), filteredAndSortedResults)
        }
    }

    func sortItems(for items: [ItemSearchResult]) async -> any SearchResults {
        switch selectedSortType {
        case .mostRecent:
            await items.asyncMostRecentSortResult()
        case .alphabeticalAsc:
            await items.asyncAlphabeticalSortResult(direction: .ascending)
        case .alphabeticalDesc:
            await items.asyncAlphabeticalSortResult(direction: .descending)
        case .newestToOldest:
            await items.asyncMonthYearSortResult(direction: .descending)
        case .oldestToNewest:
            await items.asyncMonthYearSortResult(direction: .ascending)
        }
    }
}

// MARK: - Public APIs

extension SearchViewModel {
    func refreshResults() {
        Task { [weak self] in
            guard let self else { return }
            await indexItems()
            doSearch(query: lastSearchQuery)
        }
    }

    func viewDetail(of item: any ItemIdentifiable) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let userId = try await userManager.getActiveUserId()
                if let itemContent = try await itemRepository.getItemContent(shareId: item.shareId,
                                                                             itemId: item.itemId) {
                    try await searchEntryDatasource.upsert(item: item, userId: userId, date: .now)
                    try await refreshSearchHistory()
                    addTelemetryEvent(with: .searchClick)
                    router.present(for: .itemDetail(itemContent, automaticDisplay: true))
                    if #available(iOS 17, *) {
                        await SpotlightTip.didPerformSearch.donate()
                    }
                }
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func removeFromHistory(_ item: any ItemIdentifiable) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await searchEntryDatasource.remove(item: item)
                try await refreshSearchHistory()
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func removeAllSearchHistory() {
        Task { [weak self] in
            guard let self, let vaultSelection = searchMode.vaultSelection else { return }

            do {
                if case let .precise(vault) = vaultSelection {
                    try await searchEntryDatasource.removeAllEntries(shareId: vault.shareId)
                } else {
                    let userId = try await userManager.getActiveUserId()
                    try await searchEntryDatasource.removeAllEntries(userId: userId)
                }
                try await refreshSearchHistory()
            } catch {
                router.display(element: .displayErrorBanner(error))
            }
        }
    }

    func searchInAllVaults() {
        guard searchMode != .pinned else {
            return
        }
        searchMode = .all(.all)
        refreshResults()
    }

    func openSettings() {
        router.present(for: .settingsMenu)
    }
}

// MARK: SetUP & Utils

private extension SearchViewModel {
    func setup() {
        itemRepository
            .itemsWereUpdated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                refreshResults()
            }
            .store(in: &cancellables)

        $query
            .debounce(for: 0.4, scheduler: DispatchQueue.main)
            .dropFirst()
            .removeDuplicates()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] term in
                guard let self else { return }
                doSearch(query: term)
            }
            .store(in: &cancellables)

        $selectedType
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                filterAndSortResults()
            }
            .store(in: &cancellables)

        if #available(iOS 17, *) {
            SpotlightTip.spotlightEnabled = getUserPreferences().spotlightEnabled
        }

        addTelemetryEvent(with: .searchTriggered)
    }
}

extension SearchViewState: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty), (.initializing, .initializing):
            true

        case let (.history(lhsHistory), .history(rhsHistory)):
            lhsHistory == rhsHistory

        case let (.noResults(lhsQuery), .noResults(rhsQuery)):
            lhsQuery == rhsQuery

        case let (.results(lhsItemCount, lhsResults), .results(rhsItemCount, rhsResults)):
            lhsResults.hashValue == rhsResults.hashValue &&
                lhsItemCount == rhsItemCount

        case let (.error(lhsError), .error(rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription

        default:
            false
        }
    }
}
