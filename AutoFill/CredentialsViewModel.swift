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
import CryptoKit
import SwiftUI

final class CredentialsViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded
        case error(Error)
    }

    @Published private(set) var state = State.idle
    @Published private(set) var matchedItems = [ItemListUiModel]()
    @Published private(set) var notMatchedItems = [ItemListUiModel]()

    private let itemRepository: ItemRepositoryProtocol
    private let symmetricKey: SymmetricKey
    private let urls: [URL]

    var onClose: (() -> Void)?
    var onSelect: ((ASPasswordCredential) -> Void)?

    init(itemRepository: ItemRepositoryProtocol,
         symmetricKey: SymmetricKey,
         serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.itemRepository = itemRepository
        self.symmetricKey = symmetricKey
        self.urls = serviceIdentifiers.map { $0.identifier }.compactMap { URL(string: $0) }
        fetchItems()
    }

    func fetchItems() {
        Task { @MainActor in
            do {
                state = .loading
                let encryptedItems = try await itemRepository.getItems(forceRefresh: false, state: .active)

                var matchedItems = [ItemListUiModel]()
                var notMatchedItems = [ItemListUiModel]()
                for encryptedItem in encryptedItems {
                    let decryptedItemContent =
                    try encryptedItem.getDecryptedItemContent(symmetricKey: symmetricKey)

                    if case let .login(_, _, itemUrlStrings) = decryptedItemContent.contentData {
                        let itemUrls = itemUrlStrings.compactMap { URL(string: $0) }
                        let matchedUrls = urls.filter { url in
                            if let scheme = url.scheme,
                               let host = url.host {
                                for itemUrl in itemUrls {
                                    if let itemScheme = itemUrl.scheme,
                                       let itemHost = itemUrl.host {
                                        if scheme == itemScheme && host == itemHost {
                                            return true
                                        }
                                    }
                                }
                                return false
                            } else {
                                return false
                            }
                        }

                        let decryptedItem = try await encryptedItem.toItemListUiModel(symmetricKey)
                        if matchedUrls.isEmpty {
                            notMatchedItems.append(decryptedItem)
                        } else {
                            matchedItems.append(decryptedItem)
                        }
                    }
                }

                self.matchedItems = matchedItems
                self.notMatchedItems = notMatchedItems
                state = .loaded
            } catch {
                state = .error(error)
            }
        }
    }
}

// MARK: - Actions
extension CredentialsViewModel {
    func closeAction() {
        onClose?()
    }

    func select(item: ItemListUiModel) {
        Task { @MainActor in
            do {
                guard let item = try await itemRepository.getItem(shareId: item.shareId,
                                                                  itemId: item.itemId) else {
                    return
                }
                let itemContent = try item.getDecryptedItemContent(symmetricKey: symmetricKey)
                switch itemContent.contentData {
                case let .login(username, password, _):
                    onSelect?(.init(user: username, password: password))
                default:
                    break
                }
            } catch {
                state = .error(error)
            }
        }
    }
}
