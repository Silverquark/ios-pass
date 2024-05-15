//
// PublicLinkRepository.swift
// Proton Pass - Created on 15/05/2024.
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

@preconcurrency import Combine
import Entities
import Foundation

// sourcery: AutoMockable
public protocol PublicLinkRepositoryProtocol: Sendable {
    func createPublicLink(shareId: String,
                          itemId: String,
                          revision: Int,
                          expirationTime: Int,
                          encryptedItemKey: String,
                          maxReadCount: Int?) async throws -> SharedPublicLink
    func deletePublicLink(publicLinkId: String) async throws
    func getAllPublicLinksForUser() async throws -> [PublicLink]
    func getPublicLinkContent(publicLinkToken: String) async throws -> PublicLinkContent
}

public actor PublicLinkRepository: PublicLinkRepositoryProtocol {
    private let remoteDataSource: any RemotePublicLinkDataSourceProtocol

    private var cancellable = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    public init(itemRepository: any ItemRepositoryProtocol,
                remoteDataSource: any RemotePublicLinkDataSourceProtocol,
                symmetricKeyProvider: any SymmetricKeyProvider) {
        //        self.itemRepository = itemRepository
        //        self.symmetricKeyProvider = symmetricKeyProvider
        self.remoteDataSource = remoteDataSource
    }
}

// MARK: - Public link

public extension PublicLinkRepository {
    func createPublicLink(shareId: String,
                          itemId: String,
                          revision: Int,
                          expirationTime: Int,
                          encryptedItemKey: String,
                          maxReadCount: Int?) async throws -> SharedPublicLink {
        try await remoteDataSource.createPublicLink(shareId: shareId,
                                                    itemId: itemId,
                                                    revision: revision,
                                                    expirationTime: expirationTime,
                                                    encryptedItemKey: encryptedItemKey,
                                                    maxReadCount: maxReadCount)
    }

    func deletePublicLink(publicLinkId: String) async throws {
        try await remoteDataSource.deletePublicLink(publicLinkId: publicLinkId)
    }

    func getAllPublicLinksForUser() async throws -> [PublicLink] {
        try await remoteDataSource.getAllPublicLinksForUser()
    }

    func getPublicLinkContent(publicLinkToken: String) async throws -> PublicLinkContent {
        try await remoteDataSource.getPublicLinkContent(publicLinkToken: publicLinkToken)
    }
}
