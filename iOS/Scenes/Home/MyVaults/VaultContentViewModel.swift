//
// VaultContentViewModel.swift
// Proton Pass - Created on 21/07/2022.
// Copyright (c) 2022 Proton Technologies AG
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
import SwiftUI

extension VaultContentViewModel {
    enum State {
        case loading
        case loaded
        case error(Error)

        var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }
}

protocol VaultContentViewModelDelegate: AnyObject {
    func vaultContentViewModelWantsToToggleSidebar()
    func vaultContentViewModelWantsToShowLoadingHud()
    func vaultContentViewModelWantsToHideLoadingHud()
    func vaultContentViewModelWantsToEnableAutoFill()
    func vaultContentViewModelWantsToSearch()
    func vaultContentViewModelWantsToShowVaultList()
    func vaultContentViewModelWantsToCreateItem()
    func vaultContentViewModelWantsToShowItemDetail(_ item: ItemContent)
    func vaultContentViewModelWantsToEditItem(_ item: ItemContent)
    func vaultContentViewModelWantsToCopy(text: String, bannerMessage: String)
    func vaultContentViewModelDidTrashItem(_ item: ItemIdentifiable, type: ItemContentType)
    func vaultContentViewModelDidMoveItem(_ item: ItemIdentifiable, type: ItemContentType)
    func vaultContentViewModelDidFail(_ error: Error)
}

// MARK: - Initialization
final class VaultContentViewModel: DeinitPrintable, PullToRefreshable, ObservableObject {
    deinit { print(deinitMessage) }

    private var allItems = [ItemListUiModel]()
    @Published private(set) var state = State.loading
    @Published private(set) var filteredItems = [ItemListUiModel]()
    @Published private(set) var sortTypes = SortType.allCases
    @Published var shouldShowAutoFillBanner = false
    @Published var filterOption = ItemTypeFilterOption.all {
        didSet {
            self.sortTypes = SortType.allCases
            switch filterOption {
            case .all:
                break
            case .filtered:
                sortTypes.removeAll { $0 == .type }
                if sortType == .type {
                    sortType = .modifyTime
                    return
                }
            }
            filterAndSort()
        }
    }
    @Published var sortType = SortType.modifyTime { didSet { filterAndSort() } }
    @Published var sortDirection = SortDirection.descending { didSet { filterAndSort() } }

    private let itemRepository: ItemRepositoryProtocol
    private let symmetricKey: SymmetricKey
    private let logger: Logger
    let preferences: Preferences
    let credentialManager: CredentialManagerProtocol
    let vaultSelection: VaultSelection

    private var cancellables = Set<AnyCancellable>()

    /// `PullToRefreshable` conformance
    var pullToRefreshContinuation: CheckedContinuation<Void, Never>?
    let syncEventLoop: SyncEventLoop

    weak var itemCountDelegate: ItemCountDelegate?

    var selectedVault: VaultProtocol? { vaultSelection.selectedVault }
    var vaults: [VaultProtocol] { vaultSelection.vaults }
    var otherVaults: [VaultProtocol] {
        vaultSelection.vaults.filter { $0.id != vaultSelection.selectedVault?.id }
    }

    weak var delegate: VaultContentViewModelDelegate?

    init(vaultSelection: VaultSelection,
         itemRepository: ItemRepositoryProtocol,
         credentialManager: CredentialManagerProtocol,
         symmetricKey: SymmetricKey,
         syncEventLoop: SyncEventLoop,
         preferences: Preferences,
         logManager: LogManager) {
        self.vaultSelection = vaultSelection
        self.itemRepository = itemRepository
        self.credentialManager = credentialManager
        self.symmetricKey = symmetricKey
        self.syncEventLoop = syncEventLoop
        self.preferences = preferences
        self.logger = .init(subsystem: Bundle.main.bundleIdentifier ?? "",
                            category: "\(Self.self)",
                            manager: logManager)
        showAutoFillBannerIfNecessary()

        vaultSelection.$selectedVault
            .sink { [unowned self] _ in
                self.fetchItems(showLoadingIndicator: true)
            }
            .store(in: &cancellables)
    }

    private func updateItemCount() {
        itemCountDelegate?.itemCountDidUpdate(allItems.generateItemCount())
    }

    private func filterAndSort() {
        filteredItems = allItems.filteredAndSorted(filterOption: filterOption,
                                                   type: sortType,
                                                   direction: sortDirection)
    }

    private func showAutoFillBannerIfNecessary() {
        Task { @MainActor in
            let autoFillEnabled = await credentialManager.isAutoFillEnabled()
            if !autoFillEnabled, !self.preferences.autoFillBannerDisplayed, self.preferences.onboarded {
                shouldShowAutoFillBanner = true
            }
        }
    }
}

// MARK: - Public actions
extension VaultContentViewModel {
    func toggleSidebar() {
        delegate?.vaultContentViewModelWantsToToggleSidebar()
    }

    func showVaultList() {
        delegate?.vaultContentViewModelWantsToShowVaultList()
    }

    func createItem() {
        delegate?.vaultContentViewModelWantsToCreateItem()
    }

    func search() {
        delegate?.vaultContentViewModelWantsToSearch()
    }

    func enableAutoFill() {
        delegate?.vaultContentViewModelWantsToEnableAutoFill()
        cancelAutoFillBanner()
    }

    func cancelAutoFillBanner() {
        shouldShowAutoFillBanner = false
        preferences.autoFillBannerDisplayed = true
    }

    func fetchItems(showLoadingIndicator: Bool = false) {
        guard selectedVault != nil else {
            logger.fatal("No selected vault. Skipped fetching items")
            return
        }
        Task { @MainActor in
            logger.trace("Fetching items")
            if state.isError || showLoadingIndicator {
                state = .loading
            }

            do {
                allItems = try await getItemsTask().value
                updateItemCount()
                filterAndSort()
                state = .loaded
                logger.info("Fetched \(allItems.count) items")
            } catch {
                logger.error(error)
                state = .error(error)
            }
        }
    }

    func selectItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                delegate?.vaultContentViewModelWantsToShowItemDetail(itemContent)
                logger.info("Want to view detail \(item.debugInformation)")
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func moveItem(_ item: ItemListUiModel, to vault: VaultProtocol) {
        Task { @MainActor in
            defer { delegate?.vaultContentViewModelWantsToHideLoadingHud() }
            do {
                delegate?.vaultContentViewModelWantsToShowLoadingHud()

                logger.trace("Moving \(item.debugInformation) to share \(vault.shareId)")
                let shareId = item.shareId
                let itemId = item.itemId
                guard let symmetricallyEncryptedItem =
                        try await itemRepository.getItem(shareId: shareId, itemId: itemId) else {
                    throw PPError.itemNotFound(shareID: shareId, itemID: itemId)
                }

                // Copy and create item in the other vault
                let decryptedItemContent =
                try symmetricallyEncryptedItem.getDecryptedItemContent(symmetricKey: symmetricKey)

                _ = try await createItemTask(shareId: vault.shareId,
                                             itemContent: decryptedItemContent.protobuf).value
                logger.trace("Copied \(item.debugInformation) to share \(vault.shareId)")

                // Remove item in current vault
                try await deleteItemSkippingTrashTask(for: symmetricallyEncryptedItem).value
                logger.info("Moved \(item.debugInformation) to share \(vault.shareId)")

                delegate?.vaultContentViewModelDidMoveItem(item, type: item.type)
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func editItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                delegate?.vaultContentViewModelWantsToEditItem(itemContent)
                logger.info("Want to edit \(item.debugInformation)")
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func copyNote(_ item: ItemListUiModel) {
        guard case .note = item.type else { return }
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                if case .note = itemContent.contentData {
                    delegate?.vaultContentViewModelWantsToCopy(text: itemContent.note,
                                                               bannerMessage: "Note copied")
                    logger.info("Want to copy note \(item.debugInformation)")
                }
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func copyUsername(_ item: ItemListUiModel) {
        guard case .login = item.type else { return }
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                if case .login(let data) = itemContent.contentData {
                    delegate?.vaultContentViewModelWantsToCopy(text: data.username,
                                                               bannerMessage: "Username copied")
                    logger.info("Want to copy username \(item.debugInformation)")
                }
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func copyPassword(_ item: ItemListUiModel) {
        guard case .login = item.type else { return }
        Task { @MainActor in
            do {
                let itemContent = try await getDecryptedItemContentTask(for: item).value
                if case .login(let data) = itemContent.contentData {
                    delegate?.vaultContentViewModelWantsToCopy(text: data.password,
                                                               bannerMessage: "Password copied")
                    logger.info("Want to copy password \(item.debugInformation)")
                }
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func copyEmailAddress(_ item: ItemListUiModel) {
        guard case .alias = item.type else { return }
        Task { @MainActor in
            do {
                let item = try await getItem(shareId: item.shareId, itemId: item.itemId)
                if let emailAddress = item.item.aliasEmail {
                    delegate?.vaultContentViewModelWantsToCopy(text: emailAddress,
                                                               bannerMessage: "Email address copied")
                    logger.info("Want to copy email address \(item.debugInformation)")
                }
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }

    func trashItem(_ item: ItemListUiModel) {
        Task { @MainActor in
            defer { delegate?.vaultContentViewModelWantsToHideLoadingHud() }
            delegate?.vaultContentViewModelWantsToShowLoadingHud()
            do {
                logger.trace("Trashing \(item.debugInformation)")
                try await trashItemTask(for: item).value
                fetchItems()
                delegate?.vaultContentViewModelDidTrashItem(item, type: item.type)
                logger.info("Trashed \(item.debugInformation)")
            } catch {
                logger.error(error)
                delegate?.vaultContentViewModelDidFail(error)
            }
        }
    }
}

// MARK: - Private supporting tasks
private extension VaultContentViewModel {
    func getItemsTask() -> Task<[ItemListUiModel], Error> {
        Task.detached(priority: .userInitiated) {
            guard let shareId = self.vaultSelection.selectedVault?.shareId else {
                throw PPError.vault(.noSelectedVault)
            }
            let encryptedItems = try await self.itemRepository.getItems(shareId: shareId,
                                                                        state: .active)
            return try await encryptedItems.parallelMap { try await $0.toItemListUiModel(self.symmetricKey) }
        }
    }

    func getDecryptedItemContentTask(for item: ItemListUiModel) -> Task<ItemContent, Error> {
        Task.detached(priority: .userInitiated) {
            let encryptedItem = try await self.getItem(shareId: item.shareId, itemId: item.itemId)
            return try encryptedItem.getDecryptedItemContent(symmetricKey: self.symmetricKey)
        }
    }

    func trashItemTask(for item: ItemListUiModel) -> Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            let itemToBeTrashed = try await self.getItem(shareId: item.shareId, itemId: item.itemId)
            try await self.itemRepository.trashItems([itemToBeTrashed])
        }
    }

    func deleteItemSkippingTrashTask(for item: SymmetricallyEncryptedItem) -> Task<Void, Error> {
        Task.detached(priority: .userInitiated) {
            try await self.itemRepository.deleteItems([item], skipTrash: true)
        }
    }

    func getItem(shareId: String, itemId: String) async throws -> SymmetricallyEncryptedItem {
        guard let item = try await itemRepository.getItem(shareId: shareId,
                                                          itemId: itemId) else {
            throw PPError.itemNotFound(shareID: shareId, itemID: itemId)
        }
        return item
    }

    func createItemTask(shareId: String,
                        itemContent: ItemContentProtobuf) -> Task<SymmetricallyEncryptedItem, Error> {
        Task.detached(priority: .userInitiated) {
            try await self.itemRepository.createItem(itemContent: itemContent,
                                                     shareId: shareId)
        }
    }
}

// MARK: - SyncEventLoopPullToRefreshDelegate
extension VaultContentViewModel: SyncEventLoopPullToRefreshDelegate {
    func pullToRefreshShouldStopRefreshing() {
        stopRefreshing()
    }
}

private extension Array where Element == ItemListUiModel {
    mutating func filteredAndSorted(filterOption: ItemTypeFilterOption,
                                    type: SortType,
                                    direction: SortDirection) -> Self {
        filter { item in
            switch filterOption {
            case .all:
                return true
            case .filtered(let type):
                return item.type == type
            }
        }
        .sorted { lhs, rhs in
            switch (type, direction) {
            case (.title, .ascending):
                return lhs.title < rhs.title
            case (.title, .descending):
                return lhs.title > rhs.title
            case (.type, .ascending):
                return lhs.type.rawValue < rhs.type.rawValue
            case (.type, .descending):
                return lhs.type.rawValue > rhs.type.rawValue
            case (.createTime, .ascending):
                return lhs.createTime < rhs.createTime
            case (.createTime, .descending):
                return lhs.createTime > rhs.createTime
            case (.modifyTime, .ascending):
                return lhs.modifyTime < rhs.modifyTime
            case (.modifyTime, .descending):
                return lhs.modifyTime > rhs.modifyTime
            }
        }
    }

    func generateItemCount() -> ItemCount {
        var dictionary: [ItemContentType: Int] = [:]
        for type in ItemContentType.allCases {
            let count = filter { $0.type == type }.count
            dictionary[type] = count
        }
        return .init(total: count, typeCountDictionary: dictionary)
    }
}
