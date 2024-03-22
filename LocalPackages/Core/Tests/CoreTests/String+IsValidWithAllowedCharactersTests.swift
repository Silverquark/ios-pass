//
// String+IsValidWithAllowedCharactersTests.swift
// Proton Pass - Created on 18/11/2022.
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

@testable import Core
import XCTest

//// swiftlint:disable:next type_name
//final class StringPlusIsValidWithAllowedCharactersTests: XCTestCase {
//    func testIsValidWithAllowedCharacterSet() {
//        XCTAssertTrue("abcDEF".isValid(allowedCharacters: .alphanumerics))
//        XCTAssertTrue("abcDEF012".isValid(allowedCharacters: .alphanumerics))
//        XCTAssertFalse("abcDEF012&".isValid(allowedCharacters: .alphanumerics))
//        XCTAssertFalse("😊".isValid(allowedCharacters: .alphanumerics))
//        XCTAssertFalse("".isValid(allowedCharacters: .alphanumerics))
//    }
//}
//
//extension String {
//    func isValid(allowedCharacters: CharacterSet) -> Bool {
//        guard !isEmpty else { return false }
//        for character in unicodeScalars where !allowedCharacters.contains(character) {
//            return false
//        }
//        return true
//    }
// }
