//
// HomepageTabbarView.swift
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

import Client
import Combine
import Core
import DesignSystem
import Entities
import Factory
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

enum HomepageTab: CaseIterable, Hashable {
    case items, authenticator, itemCreation, passMonitor, profile

    var image: UIImage {
        switch self {
        case .items:
            IconProvider.listBullets
        case .authenticator:
            PassIcon.tabAuthenticator
        case .itemCreation:
            IconProvider.plus
        case .passMonitor:
            IconProvider.shield
        case .profile:
            IconProvider.user
        }
    }

    var hint: String {
        switch self {
        case .items:
            "Homepage tab"
        case .authenticator:
            "2fa Authenticator tab"
        case .itemCreation:
            "Create new item button"
        case .passMonitor:
            "Pass Monitor tab"
        case .profile:
            "Profile tab"
        }
    }

    var identifier: String? {
        switch self {
        case .profile:
            "HomepageTabBarController_profileTabView"
        default:
            nil
        }
    }
}

private extension MonitorState {
    func icon(selected: Bool) -> UIImage {
        switch self {
        case let .active(state):
            switch state {
            case .noBreaches:
                selected ?
                    PassIcon.tabMonitorActiveNoBreachesSelected :
                    PassIcon.tabMonitorActiveNoBreachesUnselected
            case .noBreachesButWeakOrReusedPasswords:
                selected ?
                    PassIcon.tabMonitorActiveNoBreachesWeakReusedPasswordsSelected :
                    PassIcon.tabMonitorActiveNoBreachesWeakReusedPasswordsUnselected
            case .breachesFound:
                selected ?
                    PassIcon.tabMonitorActiveBreachesFoundSelected :
                    PassIcon.tabMonitorActiveBreachesFoundUnselected
            }
        case let .inactive(state):
            switch state {
            case .noBreaches:
                selected ?
                    PassIcon.tabMonitorInactiveNoBreachesSelected :
                    PassIcon.tabMonitorInactiveNoBreachesUnselected
            case .noBreachesButWeakOrReusedPasswords:
                selected ?
                    PassIcon.tabMonitorInactiveNoBreachesWeakReusedPasswordsSelected :
                    PassIcon.tabMonitorInactiveNoBreachesWeakReusedPasswordsUnselected
            case .breachesFound:
                selected ?
                    PassIcon.tabMonitorInactiveBreachesFoundSelected :
                    PassIcon.tabMonitorInactiveBreachesFoundUnselected
            }
        }
    }
}

@MainActor
protocol HomepageTabDelegate: AnyObject {
    func change(tab: HomepageTab)
    func refreshTabIcons()
    func hideTabbar(_ isHidden: Bool)
    func disableCreateButton(_ isDisabled: Bool)
}

struct HomepageTabbarView: UIViewControllerRepresentable {
    let itemsTabViewModel: ItemsTabViewModel
    let profileTabViewModel: ProfileTabViewModel
    let passMonitorViewModel: PassMonitorViewModel
    weak var homepageCoordinator: HomepageCoordinator?
    weak var delegate: HomepageTabBarControllerDelegate?

    init(itemsTabViewModel: ItemsTabViewModel,
         profileTabViewModel: ProfileTabViewModel,
         passMonitorViewModel: PassMonitorViewModel,
         homepageCoordinator: HomepageCoordinator? = nil,
         delegate: HomepageTabBarControllerDelegate? = nil) {
        self.itemsTabViewModel = itemsTabViewModel
        self.profileTabViewModel = profileTabViewModel
        self.homepageCoordinator = homepageCoordinator
        self.passMonitorViewModel = passMonitorViewModel
        self.delegate = delegate
    }

    func makeUIViewController(context: Context) -> HomepageTabBarController {
        let controller = HomepageTabBarController(itemsTabView: .init(viewModel: itemsTabViewModel),
                                                  profileTabView: .init(viewModel: profileTabViewModel),
                                                  passMonitorView: .init(viewModel: passMonitorViewModel))
        controller.homepageTabBarControllerDelegate = delegate
        context.coordinator.homepageTabBarController = controller
        homepageCoordinator?.homepageTabDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: HomepageTabBarController, context: Context) {}

    func makeCoordinator() -> Coordinator { .init() }

    @MainActor
    final class Coordinator: NSObject, HomepageTabDelegate {
        var homepageTabBarController: HomepageTabBarController?

        func change(tab: HomepageTab) {
            homepageTabBarController?.select(tab: tab)
        }

        func refreshTabIcons() {
            homepageTabBarController?.refreshTabBarIcons()
        }

        func hideTabbar(_ isHidden: Bool) {
            homepageTabBarController?.hideTabBar(isHidden)
        }

        func disableCreateButton(_ isDisabled: Bool) {
            homepageTabBarController?.disableCreateButton(isDisabled)
        }
    }
}

@MainActor
protocol HomepageTabBarControllerDelegate: AnyObject {
    func selected(tab: HomepageTab)
}

@MainActor
final class HomepageTabBarController: UITabBarController, DeinitPrintable, UIGestureRecognizerDelegate {
    deinit { print(deinitMessage) }

    private let itemsTabView: ItemsTabView
    private let profileTabView: ProfileTabView
    private let passMonitorView: PassMonitorView
    private var passMonitorViewController: UIViewController?
    private var profileTabViewController: UIViewController?

    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private let monitorStateStream = resolve(\DataStreamContainer.monitorStateStream)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let userDefaults: UserDefaults = .standard
    private let getFeatureFlagStatus = resolve(\SharedUseCasesContainer.getFeatureFlagStatus)
    weak var homepageTabBarControllerDelegate: HomepageTabBarControllerDelegate?

    private var previousVC: UIViewController?
    private var tabIndexes = [HomepageTab: Int]()
    private var cancellables = Set<AnyCancellable>()

    init(itemsTabView: ItemsTabView,
         profileTabView: ProfileTabView,
         passMonitorView: PassMonitorView) {
        self.itemsTabView = itemsTabView
        self.profileTabView = profileTabView
        self.passMonitorView = passMonitorView
        super.init(nibName: nil, bundle: nil)

        monitorStateStream
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                passMonitorViewController?.tabBarItem.image = state.icon(selected: false)
                passMonitorViewController?.tabBarItem.selectedImage = state.icon(selected: true)
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        var currentIndex = 0

        var controllers = [UIViewController]()
        let itemsTabViewController = UIHostingController(rootView: itemsTabView)
        itemsTabViewController.tabBarItem.image = HomepageTab.items.image
        itemsTabViewController.tabBarItem.accessibilityLabel = HomepageTab.items.hint

        tabIndexes[.items] = currentIndex
        currentIndex += 1
        controllers.append(itemsTabViewController)

        if userDefaults.bool(forKey: Constants.QA.displayAuthenticator) {
            let authenticator = UIHostingController(rootView: AuthenticatorView())
            authenticator.tabBarItem.image = HomepageTab.authenticator.image
            authenticator.tabBarItem.accessibilityHint = HomepageTab.authenticator.hint
            controllers.append(authenticator)
            tabIndexes[.authenticator] = currentIndex
            currentIndex += 1
        }

        let dummyViewController = UIViewController()
        dummyViewController.tabBarItem.image = HomepageTab.itemCreation.image
        dummyViewController.tabBarItem.accessibilityLabel = HomepageTab.itemCreation.hint
        controllers.append(dummyViewController)
        tabIndexes[.itemCreation] = currentIndex
        currentIndex += 1

        if getFeatureFlagStatus(with: FeatureFlagType.passSentinelV1) {
            let passMonitorViewController = UIHostingController(rootView: passMonitorView)
            passMonitorViewController.tabBarItem.image = MonitorState.default.icon(selected: false)
            passMonitorViewController.tabBarItem.selectedImage = MonitorState.default.icon(selected: true)
            passMonitorViewController.tabBarItem.accessibilityLabel = HomepageTab.passMonitor.hint
            controllers.append(passMonitorViewController)
            self.passMonitorViewController = passMonitorViewController
            tabIndexes[.passMonitor] = currentIndex
            currentIndex += 1
        }

        let profileTabViewController = UIHostingController(rootView: profileTabView)
        profileTabViewController.tabBarItem.image = HomepageTab.profile.image
        profileTabViewController.tabBarItem.accessibilityLabel = HomepageTab.profile.hint
        profileTabViewController.tabBarItem.accessibilityIdentifier = HomepageTab.profile.identifier
        self.profileTabViewController = profileTabViewController
        controllers.append(profileTabViewController)
        tabIndexes[.profile] = currentIndex

        viewControllers = controllers

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .regular)
        tabBarAppearance.backgroundColor = PassColor.tabBarBackground
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = PassColor.textNorm
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = PassColor.interactionNormMajor2
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance

        if let tabBarItems = tabBar.items {
            for item in tabBarItems {
                item.title = nil
                item.imageInsets = .init(top: 8, left: 0, bottom: -8, right: 0)
            }
        }

        refreshTabBarIcons()
    }
}

// MARK: - Public APIs

extension HomepageTabBarController {
    func select(tab: HomepageTab) {
        if let index = tabIndexes[tab] {
            selectedViewController = viewControllers?[index]
        }
    }

    func refreshTabBarIcons() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let plan = try await accessRepository.getPlan()

                let (image, selectedImage): (UIImage, UIImage) = switch plan.planType {
                case .free:
                    (IconProvider.user, IconProvider.user)
                case .business, .plus:
                    (PassIcon.tabProfilePaidUnselected, PassIcon.tabProfilePaidSelected)
                case .trial:
                    (PassIcon.tabProfileTrialUnselected, PassIcon.tabProfileTrialSelected)
                }

                profileTabViewController?.tabBarItem.image = image
                profileTabViewController?.tabBarItem.selectedImage = selectedImage
            } catch {
                logger.error(error)
            }
        }
    }

    func hideTabBar(_ isHidden: Bool) {
        UIView.animate(withDuration: 0.7,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.7,
                       options: .curveEaseOut) { [weak self] in
            guard let self else { return }
            if isHidden {
                tabBar.frame.origin.y = view.frame.maxY + tabBar.frame.height
            } else {
                tabBar.frame.origin.y = view.frame.maxY - tabBar.frame.height
            }
            view.layoutIfNeeded()
        }
    }

    func disableCreateButton(_ isDisabled: Bool) {
        UIView.animate(withDuration: 0.5) { [weak self] in
            guard let self, let index = tabIndexes[.itemCreation] else { return }

            viewControllers?[index].tabBarItem.isEnabled = !isDisabled
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension HomepageTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        guard let viewControllers = tabBarController.viewControllers else { return false }

        if let index = viewControllers.firstIndex(of: viewController),
           let tab = tabIndexes.first(where: { $0.value == index })?.key {
            homepageTabBarControllerDelegate?.selected(tab: tab)
            switch tab {
            case .itemCreation:
                return false
            case .authenticator:
                return !UIDevice.current.isIpad
            default:
                return true
            }
        }

        return false
    }
}
