//
// DeleteMailboxEndpoint.swift
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

import ProtonCoreNetworking

struct DeleteMailboxRequest: Encodable, Sendable {
    let transferMailboxID: Int?

    enum CodingKeys: String, CodingKey {
        case transferMailboxID = "TransferMailboxID"
    }
}

struct DeleteMailboxEndpoint: Endpoint {
    typealias Body = DeleteMailboxRequest
    typealias Response = CodeOnlyResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: DeleteMailboxRequest?

    init(mailboxID: String, transferMailboxId: Int?) {
        debugDescription = "Delete an alias mailbox"
        path = "/pass/v1/user/alias/mailbox/\(mailboxID)"
        method = .delete
        body = .init(transferMailboxID: transferMailboxId)
    }
}
