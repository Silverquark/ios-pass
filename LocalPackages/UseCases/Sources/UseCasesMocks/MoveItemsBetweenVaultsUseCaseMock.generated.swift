// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// Proton Pass.
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

@testable import UseCases
import Client

public final class MoveItemsBetweenVaultsUseCaseMock: @unchecked Sendable, MoveItemsBetweenVaultsUseCase {

    public init() {}

    // MARK: - execute
    public var executeMovingContextThrowableError: Error?
    public var closureExecute: () -> () = {}
    public var invokedExecutefunction = false
    public var invokedExecuteCount = 0
    public var invokedExecuteParameters: (movingContext: MovingContext, Void)?
    public var invokedExecuteParametersList = [(movingContext: MovingContext, Void)]()

    public func execute(movingContext: MovingContext) async throws {
        invokedExecutefunction = true
        invokedExecuteCount += 1
        invokedExecuteParameters = (movingContext, ())
        invokedExecuteParametersList.append((movingContext, ()))
        if let error = executeMovingContextThrowableError {
            throw error
        }
        closureExecute()
    }
}
