//
// CredentialsViewModel.swift
// Proton Pass - Created on 27/09/2022.
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

import AuthenticationServices
import Client
import Combine
import Core
import CryptoKit
import SwiftUI

struct CredentialsFetchResult {
    let vaults: [Vault]
    let searchableItems: [SearchableItem]
    let matchedItems: [ItemUiModel]
    let notMatchedItems: [ItemUiModel]

    var isEmpty: Bool {
        searchableItems.isEmpty && matchedItems.isEmpty && notMatchedItems.isEmpty
    }
}

protocol CredentialsViewModelDelegate: AnyObject {
    func credentialsViewModelWantsToShowLoadingHud()
    func credentialsViewModelWantsToHideLoadingHud()
    func credentialsViewModelWantsToCancel()
    func credentialsViewModelWantsToPresentSortTypeList(selectedSortType: SortType,
                                                        delegate: SortTypeListViewModelDelegate)
    func credentialsViewModelWantsToCreateLoginItem(shareId: String, url: URL?)
    func credentialsViewModelDidSelect(credential: ASPasswordCredential,
                                       item: SymmetricallyEncryptedItem,
                                       serviceIdentifiers: [ASCredentialServiceIdentifier])
    func credentialsViewModelDidFail(_ error: Error)
}

enum CredentialsViewState {
    case loading
    case loaded(CredentialsFetchResult, CredentialsViewLoadedState)
    case error(Error)
}

enum CredentialsViewLoadedState: Equatable {
    /// Empty search query
    case idle
    case searching
    case noSearchResults
    case searchResults([ItemSearchResult])

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.searching, .searching),
            (.noSearchResults, .noSearchResults),
            (.searchResults, .searchResults):
            return true
        default:
            return false
        }
    }
}

enum CredentialItem {
    case normal(ItemUiModel)
    case searchResult(ItemSearchResult)
}

final class CredentialsViewModel: ObservableObject, PullToRefreshable {
    @Published private(set) var state = CredentialsViewState.loading

    @AppStorage(Constants.sortTypeKey, store: kSharedUserDefaults)
    var selectedSortType = SortType.mostRecent

    private let searchTermSubject = PassthroughSubject<String, Never>()
    private var lastTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let shareRepository: ShareRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol
    private let symmetricKey: SymmetricKey
    private let serviceIdentifiers: [ASCredentialServiceIdentifier]
    private let logger: Logger
    let favIconRepository: FavIconRepositoryProtocol
    let logManager: LogManager
    let urls: [URL]

    weak var delegate: CredentialsViewModelDelegate?

    /// `PullToRefreshable` conformance
    var pullToRefreshContinuation: CheckedContinuation<Void, Never>?
    let syncEventLoop: SyncEventLoop

    init(userId: String,
         shareRepository: ShareRepositoryProtocol,
         shareEventIDRepository: ShareEventIDRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol,
         shareKeyRepository: ShareKeyRepositoryProtocol,
         remoteSyncEventsDatasource: RemoteSyncEventsDatasourceProtocol,
         favIconRepository: FavIconRepositoryProtocol,
         symmetricKey: SymmetricKey,
         serviceIdentifiers: [ASCredentialServiceIdentifier],
         logManager: LogManager) {
        self.shareRepository = shareRepository
        self.itemRepository = itemRepository
        self.favIconRepository = favIconRepository
        self.symmetricKey = symmetricKey
        self.serviceIdentifiers = serviceIdentifiers
        self.urls = serviceIdentifiers.map { serviceIdentifier in
            switch serviceIdentifier.type {
            case .URL:
                // Web context
                return serviceIdentifier.identifier
            case .domain:
                // App context
                return "https://\(serviceIdentifier.identifier)"
            @unknown default:
                return serviceIdentifier.identifier
            }
        }.compactMap { URL(string: $0) }

        self.syncEventLoop = .init(userId: userId,
                                   shareRepository: shareRepository,
                                   shareEventIDRepository: shareEventIDRepository,
                                   remoteSyncEventsDatasource: remoteSyncEventsDatasource,
                                   itemRepository: itemRepository,
                                   shareKeyRepository: shareKeyRepository,
                                   logManager: logManager)

        self.logManager = logManager
        self.logger = .init(manager: logManager)

        self.syncEventLoop.delegate = self
        syncEventLoop.start()
        fetchItems()
        searchTermSubject
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [unowned self] term in
                self.doSearch(term: term)
            }
            .store(in: &cancellables)
    }

    private func doSearch(term: String) {
        guard case let .loaded(fetchResult, _) = state else { return }

        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            state = .loaded(fetchResult, .idle)
            return
        }

        lastTask?.cancel()
        lastTask = Task { @MainActor in
            let hashedTerm = term.sha256
            logger.trace("Searching for term \(hashedTerm)")
            state = .loaded(fetchResult, .searching)
            let searchResults = fetchResult.searchableItems.result(for: term)
            if searchResults.isEmpty {
                state = .loaded(fetchResult, .noSearchResults)
                logger.trace("No results for term \(hashedTerm)")
            } else {
                state = .loaded(fetchResult, .searchResults(searchResults))
                logger.trace("Found results for term \(hashedTerm)")
            }
        }
    }
}

// MARK: - Public actions
extension CredentialsViewModel {
    func cancel() {
        delegate?.credentialsViewModelWantsToCancel()
    }

    func fetchItems() {
        Task { @MainActor in
            do {
                logger.trace("Loading log in items")
                if case .error = state {
                    state = .loading
                }

                let result = try await fetchCredentialsTask().value
                state = .loaded(result, .idle)
                logger.info("Loaded log in items")
            } catch {
                logger.error(error)
                state = .error(error)
            }
        }
    }

    func presentSortTypeList() {
        delegate?.credentialsViewModelWantsToPresentSortTypeList(selectedSortType: selectedSortType,
                                                                 delegate: self)
    }

    func associateAndAutofill(item: ItemIdentifiable) {
        Task { @MainActor in
            defer { delegate?.credentialsViewModelWantsToHideLoadingHud() }
            delegate?.credentialsViewModelWantsToShowLoadingHud()
            do {
                logger.trace("Associate and autofilling \(item.debugInformation)")
                let encryptedItem = try await getItemTask(item: item).value
                let oldContent = try encryptedItem.getDecryptedItemContent(symmetricKey: symmetricKey)
                guard case .login(let oldData) = oldContent.contentData else {
                    throw PPError.credentialProvider(.notLogInItem)
                }
                guard let newUrl = urls.first?.schemeAndHost, !newUrl.isEmpty else {
                    throw PPError.credentialProvider(.invalidURL(urls.first))
                }
                let newLoginData = ItemContentData.login(.init(username: oldData.username,
                                                               password: oldData.password,
                                                               totpUri: oldData.totpUri,
                                                               urls: oldData.urls + [newUrl]))
                let newContent = ItemContentProtobuf(name: oldContent.name,
                                                     note: oldContent.note,
                                                     itemUuid: oldContent.itemUuid,
                                                     data: newLoginData)
                try await itemRepository.updateItem(oldItem: encryptedItem.item,
                                                    newItemContent: newContent,
                                                    shareId: encryptedItem.shareId)
                select(item: item)
                logger.info("Associate and autofill successfully \(item.debugInformation)")
            } catch {
                logger.error(error)
                state = .error(error)
            }
        }
    }

    func select(item: ItemIdentifiable) {
        Task { @MainActor in
            do {
                logger.trace("Selecting \(item.debugInformation)")
                let (credential, item) = try await getCredentialTask(for: item).value
                delegate?.credentialsViewModelDidSelect(credential: credential,
                                                        item: item,
                                                        serviceIdentifiers: serviceIdentifiers)
                logger.info("Selected \(item.debugInformation)")
            } catch {
                logger.error(error)
                state = .error(error)
            }
        }
    }

    func search(term: String) {
        if term.isEmpty {
            doSearch(term: term)
        } else {
            searchTermSubject.send(term)
        }
    }

    func handleAuthenticationFailure() {
        delegate?.credentialsViewModelDidFail(PPError.credentialProvider(.failedToAuthenticate))
    }

    func createLoginItem() {
        guard case .loaded = state else { return }
        Task { @MainActor in
            let vaults = try await shareRepository.getVaults()
            guard let primaryVault = vaults.first(where: { $0.isPrimary }) ?? vaults.first else { return }
            delegate?.credentialsViewModelWantsToCreateLoginItem(shareId: primaryVault.shareId,
                                                                 url: urls.first)
        }
    }
}

// MARK: - Private supporting tasks
private extension CredentialsViewModel {
    func getItemTask(item: ItemIdentifiable) -> Task<SymmetricallyEncryptedItem, Error> {
        Task.detached(priority: .userInitiated) {
            guard let encryptedItem =
                    try await self.itemRepository.getItem(shareId: item.shareId,
                                                          itemId: item.itemId) else {
                throw PPError.itemNotFound(shareID: item.shareId, itemID: item.itemId)
            }
            return encryptedItem
        }
    }

    func fetchCredentialsTask() -> Task<CredentialsFetchResult, Error> {
        Task.detached(priority: .userInitiated) {
            let vaults = try await self.shareRepository.getVaults()
            let encryptedItems = try await self.itemRepository.getActiveLogInItems()
            self.logger.debug("Mapping \(encryptedItems.count) encrypted items")

            let domainParser = try DomainParser()
            var searchableItems = [SearchableItem]()
            var matchedEncryptedItems = [ScoredSymmetricallyEncryptedItem]()
            var notMatchedEncryptedItems = [SymmetricallyEncryptedItem]()
            for encryptedItem in encryptedItems {
                let decryptedItemContent =
                try encryptedItem.getDecryptedItemContent(symmetricKey: self.symmetricKey)

                if case .login(let data) = decryptedItemContent.contentData {
                    searchableItems.append(try SearchableItem(from: encryptedItem,
                                                              symmetricKey: self.symmetricKey,
                                                              allVaults: vaults))

                    let itemUrls = data.urls.compactMap { URL(string: $0) }
                    var matchResults = [URLUtils.Matcher.MatchResult]()
                    for itemUrl in itemUrls {
                        for url in self.urls {
                            let result = URLUtils.Matcher.compare(itemUrl, url, domainParser: domainParser)
                            if case .matched = result {
                                matchResults.append(result)
                            }
                        }
                    }

                    if matchResults.isEmpty {
                        notMatchedEncryptedItems.append(encryptedItem)
                    } else {
                        let totalScore = matchResults.reduce(into: 0) { partialResult, next in
                            partialResult += next.score
                        }
                        matchedEncryptedItems.append(.init(item: encryptedItem,
                                                           matchScore: totalScore))
                    }
                }
            }

            let matchedItems = try await matchedEncryptedItems.sorted()
                .parallelMap { try $0.item.toItemUiModel(self.symmetricKey) }
            let notMatchedItems = try await notMatchedEncryptedItems.sorted()
                .parallelMap { try $0.toItemUiModel(self.symmetricKey) }

            self.logger.debug("Mapped \(encryptedItems.count) encrypted items.")
            self.logger.debug("\(vaults.count) vaults, \(searchableItems.count) searchable items")
            self.logger.debug("\(matchedItems.count) matched items, \(notMatchedItems.count) not matched items")
            return .init(vaults: vaults,
                         searchableItems: searchableItems,
                         matchedItems: matchedItems,
                         notMatchedItems: notMatchedItems)
        }
    }

    func getCredentialTask(for item: ItemIdentifiable)
    -> Task<(ASPasswordCredential, SymmetricallyEncryptedItem), Error> {
        Task.detached(priority: .userInitiated) {
            guard let item = try await self.itemRepository.getItem(shareId: item.shareId,
                                                                   itemId: item.itemId) else {
                throw PPError.itemNotFound(shareID: item.shareId, itemID: item.itemId)
            }
            let itemContent = try item.getDecryptedItemContent(symmetricKey: self.symmetricKey)

            switch itemContent.contentData {
            case .login(let data):
                let credential = ASPasswordCredential(user: data.username, password: data.password)
                return (credential, item)
            default:
                throw PPError.credentialProvider(.notLogInItem)
            }
        }
    }
}

// MARK: - SortTypeListViewModelDelegate
extension CredentialsViewModel: SortTypeListViewModelDelegate {
    func sortTypeListViewDidSelect(_ sortType: SortType) {
        selectedSortType = sortType
    }
}

// MARK: - SyncEventLoopPullToRefreshDelegate
extension CredentialsViewModel: SyncEventLoopPullToRefreshDelegate {
    func pullToRefreshShouldStopRefreshing() {
        stopRefreshing()
    }
}

// MARK: - SyncEventLoopDelegate
extension CredentialsViewModel: SyncEventLoopDelegate {
    func syncEventLoopDidStartLooping() {
        logger.info("Started looping")
    }

    func syncEventLoopDidStopLooping() {
        logger.info("Stopped looping")
    }

    func syncEventLoopDidBeginNewLoop() {
        logger.info("Began new sync loop")
    }

    #warning("Handle no connection reason")
    func syncEventLoopDidSkipLoop(reason: SyncEventLoopSkipReason) {
        logger.info("Skipped sync loop \(reason)")
    }

    func syncEventLoopDidFinishLoop(hasNewEvents: Bool) {
        if hasNewEvents {
            logger.info("Has new events. Refreshing items")
            fetchItems()
        } else {
            logger.info("Has no new events. Do nothing.")
        }
    }

    func syncEventLoopDidFailLoop(error: Error) {
        // Silently fail & not show error to users
        logger.error(error)
    }
}

protocol TitledItemIdentifiable: ItemIdentifiable {
    var itemTitle: String { get }
}

extension ItemUiModel: TitledItemIdentifiable {
    var itemTitle: String { title }
}

extension ItemSearchResult: TitledItemIdentifiable {
    var itemTitle: String { highlightableTitle.fullText }
}

extension CredentialItem: DateSortable, AlphabeticalSortable, Identifiable {
    var id: String {
        switch self {
        case .normal(let itemUiModel):
            return itemUiModel.itemId + itemUiModel.shareId
        case .searchResult(let itemSearchResult):
            return itemSearchResult.itemId + itemSearchResult.shareId
        }
    }

    var dateForSorting: Date {
        switch self {
        case .normal(let itemUiModel):
            return itemUiModel.dateForSorting
        case .searchResult(let itemSearchResult):
            return itemSearchResult.dateForSorting
        }
    }

    var alphabeticalSortableString: String {
        switch self {
        case .normal(let itemUiModel):
            return itemUiModel.alphabeticalSortableString
        case .searchResult(let itemSearchResult):
            return itemSearchResult.alphabeticalSortableString
        }
    }
}
