//
// OrganizationEntity.swift
// Proton Pass - Created on 14/03/2024.
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

import CoreData
import Entities

@objc(OrganizationEntity)
final class OrganizationEntity: NSManagedObject {}

extension OrganizationEntity: Identifiable {}

extension OrganizationEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<OrganizationEntity> {
        NSFetchRequest<OrganizationEntity>(entityName: "OrganizationEntity")
    }

    @NSManaged var userID: String
    @NSManaged var canUpdate: Bool
    @NSManaged var exportMode: Int64
    @NSManaged var forceLockSeconds: Int64
    @NSManaged var shareMode: Int64
    @NSManaged var passwordPolicy: Data?
}

extension OrganizationEntity {
    var toOrganization: Organization {
        let settings: Organization.Settings?
        if shareMode == -1 || exportMode == -1 || forceLockSeconds == -1 {
            settings = nil
        } else {
            let shareMode = Organization.ShareMode(rawValue: Int(shareMode)) ?? .default
            let exportMode = Organization.ExportMode(rawValue: Int(exportMode)) ?? .default
            let passwordPolicy: PasswordPolicy? = if let policyData = passwordPolicy,
                                                     let encodedPolicy = try? JSONDecoder()
                                                     .decode((PasswordPolicy?).self,
                                                             from: policyData) {
                encodedPolicy
            } else {
                nil
            }
            settings = .init(shareMode: shareMode,
                             forceLockSeconds: Int(forceLockSeconds),
                             exportMode: exportMode,
                             passwordPolicy: passwordPolicy)
        }
        return .init(canUpdate: canUpdate, settings: settings)
    }

    func hydrate(from org: Organization, userId: String) {
        userID = userId
        canUpdate = org.canUpdate
        exportMode = Int64(org.settings?.exportMode.rawValue ?? -1)
        forceLockSeconds = Int64(org.settings?.forceLockSeconds ?? -1)
        shareMode = Int64(org.settings?.shareMode.rawValue ?? -1)
        passwordPolicy = if let policy = org.settings?.passwordPolicy,
                            let encodedPolicy = try? JSONEncoder().encode(policy) {
            encodedPolicy
        } else {
            nil
        }
    }
}
