//
// MyVaultsCoordinator.swift
// Proton Pass - Created on 07/07/2022.
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

import Client
import Core
import CoreData
import ProtonCore_Login
import ProtonCore_Services
import SwiftUI
import UIComponents

protocol MyVaultsCoordinatorDelegate: AnyObject {
    func myVautsCoordinatorWantsToShowSidebar()
    func myVautsCoordinatorWantsToShowLoadingHud()
    func myVautsCoordinatorWantsToHideLoadingHud()
    func myVautsCoordinatorWantsToAlertError(_ error: Error)
}

final class MyVaultsCoordinator: Coordinator {
    weak var delegate: MyVaultsCoordinatorDelegate?

    private let apiService: APIService
    private let sessionData: SessionData
    private let vaultSelection: VaultSelection
    private let vaultContentViewModel: VaultContentViewModel
    private let shareRepository: ShareRepositoryProtocol

    init(apiService: APIService,
         sessionData: SessionData,
         vaultSelection: VaultSelection) {
        self.apiService = apiService
        self.sessionData = sessionData
        self.vaultSelection = vaultSelection

        let container = NSPersistentContainer.Builder.build(name: kProtonPassContainerName,
                                                            inMemory: false)

        let userId = sessionData.userData.user.ID
        let authCredential = sessionData.userData.credential

        // Init ShareRepository
        let localShareDatasource = LocalShareDatasource(container: container)
        let remoteShareDatasource = RemoteShareDatasource(authCredential: authCredential,
                                                          apiService: apiService)
        let shareRepository = ShareRepository(userId: userId,
                                              localShareDatasource: localShareDatasource,
                                              remoteShareDatasouce: remoteShareDatasource)
        self.shareRepository = shareRepository

        // Init ItemRevisionRepository
        let localItemRevisionDatasource = LocalItemRevisionDatasource(container: container)
        let remoteItemRevisionDatasouce =
        RemoteItemRevisionDatasource(authCredential: authCredential, apiService: apiService)
        let itemRevisionRepository =
        ItemRevisionRepository(localItemRevisionDatasoure: localItemRevisionDatasource,
                               remoteItemRevisionDatasource: remoteItemRevisionDatasouce)

        // Init ShareKeysRepository
        let localItemKeyDatasource = LocalItemKeyDatasource(container: container)
        let localVaultKeyDatasource = LocalVaultKeyDatasource(container: container)
        let localShareKeysDatasource =
        LocalShareKeysDatasource(localItemKeyDatasource: localItemKeyDatasource,
                                 localVaultKeyDatasource: localVaultKeyDatasource)
        let remoteShareKeysDatasource =
        RemoteShareKeysDatasource(authCredential: authCredential,
                                  apiService: apiService)
        let shareKeysRepository =
        ShareKeysRepository(localShareKeysDatasource: localShareKeysDatasource,
                            remoteShareKeysDatasource: remoteShareKeysDatasource)

        vaultContentViewModel = .init(userData: sessionData.userData,
                                      vaultSelection: vaultSelection,
                                      shareRepository: shareRepository,
                                      itemRevisionRepository: itemRevisionRepository,
                                      shareKeysRepository: shareKeysRepository)
        super.init()

        let myVaultsViewModel = MyVaultsViewModel(vaultSelection: vaultSelection)
        let loadVaultsViewModel = LoadVaultsViewModel(userData: sessionData.userData,
                                                      vaultSelection: vaultSelection,
                                                      shareRepository: shareRepository,
                                                      shareKeysRepository: shareKeysRepository)

        vaultContentViewModel.delegate = self
        loadVaultsViewModel.delegate = self
        self.start(with: MyVaultsView(myVaultsViewModel: myVaultsViewModel,
                                      loadVaultsViewModel: loadVaultsViewModel,
                                      vaultContentViewModel: vaultContentViewModel))
    }

    func showSidebar() {
        delegate?.myVautsCoordinatorWantsToShowSidebar()
    }

    func showCreateItemView() {
        let createItemViewModel = CreateItemViewModel()
        createItemViewModel.delegate = self
        let createItemView = CreateItemView(viewModel: createItemViewModel)
        let createItemViewController = UIHostingController(rootView: createItemView)
        if #available(iOS 15.0, *) {
            createItemViewController.sheetPresentationController?.detents = [.medium()]
        }
        presentViewController(createItemViewController)
    }

    func showCreateVaultView() {
        let createVaultViewModel =
        CreateVaultViewModel(userData: sessionData.userData,
                             shareRepository: shareRepository)
        createVaultViewModel.delegate = self
        let createVaultView = CreateVaultView(viewModel: createVaultViewModel)
        let createVaultViewController = UIHostingController(rootView: createVaultView)
        if #available(iOS 15.0, *) {
            createVaultViewController.sheetPresentationController?.detents = [.medium()]
        }
        presentViewController(createVaultViewController)
    }

    func showCreateLoginView() {
        let createLoginViewModel = CreateLoginViewModel()
        createLoginViewModel.delegate = self
        let createLoginView = CreateLoginView(viewModel: createLoginViewModel)
        presentViewFullScreen(createLoginView)
    }

    func showCreateAliasView() {
        let createAliasViewModel = CreateAliasViewModel()
        createAliasViewModel.delegate = self
        let createAliasView = CreateAliasView(viewModel: createAliasViewModel)
        presentView(createAliasView)
    }

    func showCreateNoteView() {
        let createNoteViewModel = CreateNoteViewModel()
        createNoteViewModel.delegate = self
        let createNoteView = CreateNoteView(viewModel: createNoteViewModel)
        let createNewNoteController = UIHostingController(rootView: createNoteView)
        if #available(iOS 15, *) {
            createNewNoteController.sheetPresentationController?.detents = [.medium()]
        }
        presentViewController(createNewNoteController)
    }

    func showGeneratePasswordView(delegate: GeneratePasswordViewModelDelegate?) {
        let viewModel = GeneratePasswordViewModel()
        viewModel.delegate = delegate
        let generatePasswordView = GeneratePasswordView(viewModel: viewModel)
        let generatePasswordViewController = UIHostingController(rootView: generatePasswordView)
        if #available(iOS 15, *) {
            generatePasswordViewController.sheetPresentationController?.detents = [.medium()]
        }
        presentViewController(generatePasswordViewController)
    }

    func showSearchView() {
        presentViewFullScreen(SearchView())
    }
}

// MARK: - LoadVaultsViewModelDelegate
extension MyVaultsCoordinator: LoadVaultsViewModelDelegate {
    func loadVaultsViewModelWantsToToggleSideBar() {
        showSidebar()
    }
}

// MARK: - VaultContentViewModelDelegate
extension MyVaultsCoordinator: VaultContentViewModelDelegate {
    func vaultContentViewModelWantsToToggleSidebar() {
        showSidebar()
    }

    func vaultContentViewModelWantsToSearch() {
        showSearchView()
    }

    func vaultContentViewModelWantsToCreateNewItem() {
        showCreateItemView()
    }

    func vaultContentViewModelWantsToCreateNewVault() {
        showCreateVaultView()
    }

    func vaultContentViewModelDidFailWithError(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }
}

// MARK: - CreateItemViewModelDelegate
extension MyVaultsCoordinator: CreateItemViewModelDelegate {
    func createItemViewDidSelect(option: CreateNewItemOption) {
        dismissTopMostViewController(animated: true) { [unowned self] in
            switch option {
            case .login:
                showCreateLoginView()
            case .alias:
                showCreateAliasView()
            case .note:
                showCreateNoteView()
            case .password:
                showGeneratePasswordView(delegate: nil)
            }
        }
    }
}

// MARK: - CreateVaultViewModelDelegate
extension MyVaultsCoordinator: CreateVaultViewModelDelegate {
    func createVaultViewModelBeginsLoading() {
        delegate?.myVautsCoordinatorWantsToShowLoadingHud()
    }

    func createVaultViewModelStopsLoading() {
        delegate?.myVautsCoordinatorWantsToHideLoadingHud()
    }

    func createVaultViewModelDidCreateShare(share: Share) {
        // Set vaults to empty to trigger refresh
        vaultSelection.update(vaults: [])
        dismissTopMostViewController()
    }

    func createVaultViewModelDidFailWithError(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }
}

// MARK: - CreateLoginViewModelDelegate
extension MyVaultsCoordinator: CreateLoginViewModelDelegate {
    func createLoginViewModelBeginsLoading() {
        delegate?.myVautsCoordinatorWantsToShowLoadingHud()
    }

    func createLoginViewModelStopsLoading() {
        delegate?.myVautsCoordinatorWantsToHideLoadingHud()
    }

    func createLoginViewModelWantsToGeneratePassword(delegate: GeneratePasswordViewModelDelegate) {
        showGeneratePasswordView(delegate: delegate)
    }

    func createLoginViewModelDidFailWithError(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }

    func createLoginViewModelDidCreateLogin() {
        vaultContentViewModel.fetchItems(forceRefresh: true)
    }
}

// MARK: - CreateAliasViewModelDelegate
extension MyVaultsCoordinator: CreateAliasViewModelDelegate {
    func createAliasViewModelBeginsLoading() {
        delegate?.myVautsCoordinatorWantsToShowLoadingHud()
    }

    func createAliasViewModelStopsLoading() {
        delegate?.myVautsCoordinatorWantsToHideLoadingHud()
    }

    func createAliasViewModelDidFailWithError(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }
}

// MARK: - CreateNoteViewModelDelegate
extension MyVaultsCoordinator: CreateNoteViewModelDelegate {
    func createNoteViewModelBeginsLoading() {
        delegate?.myVautsCoordinatorWantsToShowLoadingHud()
    }

    func createNoteViewModelStopsLoading() {
        delegate?.myVautsCoordinatorWantsToHideLoadingHud()
    }

    func createNoteViewModelDidFailWithError(error: Error) {
        delegate?.myVautsCoordinatorWantsToAlertError(error)
    }
}
