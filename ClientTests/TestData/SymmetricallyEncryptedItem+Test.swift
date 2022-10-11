//
// SymmetricallyEncryptedItem.swift
// Proton Pass - Created on 20/09/2022.
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

@testable import Client

extension SymmetricallyEncryptedItem {
    static func random(shareId: String? = nil,
                       item: ItemRevision? = nil,
                       encryptedContent: String? = nil,
                       type: ItemType = .random()) -> SymmetricallyEncryptedItem {
        .init(shareId: shareId ?? .random(),
              item: item ?? .random(),
              encryptedContent: encryptedContent ?? .random(),
              type: type)
    }
}

extension SymmetricallyEncryptedItem.ItemType {
    static func random() -> Self {
        if Bool.random() {
            return randomLogInType()
        }
        return .other
    }

    static func randomLogInType() -> Self {
        .logIn(.random(in: 1_234_567...1_987_654))
    }
}
