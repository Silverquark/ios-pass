//
// ItemsForTextInsertionViewModel.swift
// Proton Pass - Created on 27/09/2024.
// Copyright (c) 2024 Proton Technologies AG
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
import Core
import Entities
import Factory
import SwiftUI

enum ItemsForTextInsertionViewState: Equatable {
    /// Empty search query
    case idle
    case searching
    case searchResults([ItemSearchResult])
    case loading
    case error(any Error)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.error(lhsError), .error(rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription
        case (.idle, .idle),
             (.loading, .loading),
             (.searching, .searching),
             (.searchResults, .searchResults):
            true
        default:
            false
        }
    }
}

struct SelectedItem {
    let userId: String?
    let item: ItemContent
    let vault: Vault?
}

@MainActor
final class ItemsForTextInsertionViewModel: AutoFillViewModel<ItemsForTextInsertion> {
    @Published private(set) var state = CredentialsViewState.loading
    @Published var query = ""
    @Published var selectedItem: SelectedItem?

    @LazyInjected(\AutoFillUseCaseContainer.fetchItemsForTextInsertion)
    private var fetchItemsForTextInsertion

    @LazyInjected(\SharedRepositoryContainer.itemRepository)
    private var itemRepository

    @AppStorage(Constants.sortTypeKey, store: kSharedUserDefaults)
    var sortType = SortType.mostRecent

    @AppStorage(Constants.filterTypeKey, store: kSharedUserDefaults)
    var filterOption = ItemTypeFilterOption.all

    private var searchableItems: [SearchableItem] {
        if let selectedUser {
            results.first { $0.userId == selectedUser.id }?.searchableItems ?? []
        } else {
            getAllObjects(\.searchableItems)
        }
    }

    var items: [ItemUiModel] {
        if let selectedUser {
            results.first { $0.userId == selectedUser.id }?.items ?? []
        } else {
            getAllObjects(\.items)
        }
    }

    var itemCount: ItemCount {
        .init(items: items)
    }

    private var vaults: [Vault] {
        results.flatMap(\.vaults)
    }

    override func getVaults(userId: String) -> [Vault]? {
        results.first { $0.userId == userId }?.vaults
    }

    override func isErrorState() -> Bool {
        if case .error = state {
            true
        } else {
            false
        }
    }

    override func fetchAutoFillCredentials(userId: String) async throws -> ItemsForTextInsertion {
        try await fetchItemsForTextInsertion(userId: userId)
    }

    override func changeToErrorState(_ error: any Error) {
        state = .error(error)
    }

    override func changeToLoadingState() {
        state = .loading
    }

    override func changeToLoadedState() {
        state = .idle
    }
}

extension ItemsForTextInsertionViewModel {
    func select(_ item: any ItemIdentifiable) {
        Task { [weak self] in
            guard let self else { return }
            do {
                if let itemContent = try await itemRepository.getItemContent(shareId: item.shareId,
                                                                             itemId: item.itemId) {
                    let user = getUser(for: item, forUiDisplay: false)
                    selectedItem = .init(userId: user?.id,
                                         item: itemContent,
                                         vault: vaults.first(where: { $0.shareId == item.shareId }))
                }
            } catch {
                handle(error)
            }
        }
    }

    func autofill(_ text: String) {
        guard #available(iOS 18, *) else { return }
        context?.completeRequest(withTextToInsert: text)
    }
}
