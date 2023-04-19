//
// PrimaryPlanProvider.swift
// Proton Pass - Created on 03/04/2023.
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

import ProtonCore_Authentication
import ProtonCore_DataModel
import ProtonCore_Services

public enum PrimaryPlanProvider {
    /// Return `nil` if user is not subscribed, primary `Plan` object otherwise
    public static func getPrimaryPlan(apiService: APIService) async throws -> PlanLite? {
        let user = try await getUser(apiService: apiService)
        guard user.subscribed.isEmpty == false else { return nil }
        let subscription = try await apiService.exec(endpoint: GetSubscriptionEndpoint()).subscription
        return subscription.plans.first(where: { $0.isPrimary })
    }
}

private extension PrimaryPlanProvider {
    static func getUser(apiService: APIService) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            let authenticator = Authenticator(api: apiService)
            authenticator.getUserInfo { result in
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
