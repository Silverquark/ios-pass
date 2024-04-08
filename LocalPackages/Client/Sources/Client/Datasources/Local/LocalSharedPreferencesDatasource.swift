//
// LocalSharedPreferencesDatasource.swift
// Proton Pass - Created on 03/04/2024.
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
//

// swiftlint:disable:next todo
// TODO: remove periphery ignore
// periphery:ignore:all
import Core
import Entities
import Foundation

private let kSharedPreferencesKey = "SharedPreferences"

/// Store symmetrically encrypted `SharedPreferences` in keychain
public protocol LocalSharedPreferencesDatasourceProtocol: Sendable {
    func getPreferences() throws -> SharedPreferences?
    func upsertPreferences(_ preferences: SharedPreferences) throws
    func removePreferences() throws
}

public final class LocalSharedPreferencesDatasource: LocalSharedPreferencesDatasourceProtocol {
    private let symmetricKeyProvider: any SymmetricKeyProvider
    private let keychain: any KeychainProtocol

    public init(symmetricKeyProvider: any SymmetricKeyProvider,
                keychain: any KeychainProtocol) {
        self.symmetricKeyProvider = symmetricKeyProvider
        self.keychain = keychain
    }
}

public extension LocalSharedPreferencesDatasource {
    func getPreferences() throws -> SharedPreferences? {
        guard let encryptedData = try keychain.dataOrError(forKey: kSharedPreferencesKey) else {
            return nil
        }
        let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
        let decryptedData = try symmetricKey.decrypt(encryptedData)
        return try JSONDecoder().decode(SharedPreferences.self, from: decryptedData)
    }

    func upsertPreferences(_ preferences: SharedPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
        let encryptedData = try symmetricKey.encrypt(data)
        try keychain.setOrError(encryptedData, forKey: kSharedPreferencesKey)
    }

    func removePreferences() throws {
        try keychain.removeOrError(forKey: kSharedPreferencesKey)
    }
}
