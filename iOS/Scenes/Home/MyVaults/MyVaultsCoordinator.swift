//
// MyVaultsCoordinator.swift
// Proton Pass - Created on 07/07/2022.
// Copyright (c) 2022 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Key is free software: you can redistribute it and/or modify
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

import Core
import SwiftUI
import UIKit

protocol MyVaultsCoordinatorDelegate: AnyObject {
    func myVautsCoordinatorWantsToShowSidebar()
}

final class MyVaultsCoordinator: Coordinator {
    weak var delegate: MyVaultsCoordinatorDelegate?

    private lazy var myVaultsViewController: UIViewController = {
        let myVaultsView = MyVaultsView(coordinator: self)
        return UIHostingController(rootView: myVaultsView)
    }()

    override var root: Presentable { myVaultsViewController }

    convenience init() {
        self.init(router: .init(), navigationType: .newFlow(hideBar: false))
    }

    func showSidebar() {
        delegate?.myVautsCoordinatorWantsToShowSidebar()
    }

    func showCreateItemView() {
        let createItemView = CreateItemView()
        router.present(UIHostingController(rootView: createItemView), animated: true)
    }
}

extension MyVaultsCoordinator {
    /// For preview purposes
    static var preview: MyVaultsCoordinator { .init() }
}
