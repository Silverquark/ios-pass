//
// ShareKeyArray+LatestKeyTests.swift
// Proton Pass - Created on 23/02/2023.
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

@testable import Client
import XCTest

final class ShareKeyArrayPlusLatestKeyTests: XCTestCase {
    func testGetLatestKey() throws {
        // Given
        let key1 = ShareKey(key: .random(), keyRotation: 13)
        let key2 = ShareKey(key: .random(), keyRotation: 578)
        let key3 = ShareKey(key: .random(), keyRotation: 182)

        // When
        let latestKey = try [key1, key2, key3].latestKey()

        // Then
        XCTAssertEqual(latestKey, key2)
    }
}
