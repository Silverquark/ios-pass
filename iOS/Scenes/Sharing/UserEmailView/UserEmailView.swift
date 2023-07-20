//
//
// UserEmailView.swift
// Proton Pass - Created on 19/07/2023.
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
//

import Factory
import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

extension View {
    @ViewBuilder
    func navigationModifier() -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                self
            }
        } else {
            NavigationView {
                self
            }
        }
    }
}

//    .routingProvided
//    .withSheetDestinations(sheetDestinations: $router.presentedSheet)
//    .navigationStackEmbeded(with: $router.path)
//
//
// @MainActor
// extension View {
//    var routingProvided: some View {
//        navigationDestination(for: RouterDestination.self) { destination in
//            EmptyView()
////            switch destination {
////            case let .photoDetail(photo):
////                DetailView(viewModel: DetailViewModel(photo: photo))
////            default:
////                Text("Not implemented yet")
////            }
//        }
//    }
//
//    func withSheetDestinations(sheetDestinations: Binding<SheetDestination?>) -> some View {
//        sheet(item: sheetDestinations) { destination in
//            EmptyView()
////            switch destination {
////            case .searchSettings:
////                SearchSettingsView()
////                    .presentationDetents([.medium, .large])
////                    .presentationBackground(.ultraThinMaterial)
////            }
//        }
//    }
//
// }
//
//
// public extension View {
//    @ViewBuilder
//    func navigationStackEmbeded(with path: Binding<NavigationPath>) -> some View {
//        NavigationStack(path: path) {
//            self
//        }
//    }
// }

struct UserEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserEmailViewModel()
    private var router = resolve(\RouterContainer.mainNavViewRouter)
    @FocusState private var defaultFocus: Bool
    @State private var isShowingDetailView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 31) {
            NavigationLink(destination: router.navigate(to: .userSharePermission),
                           isActive: $isShowingDetailView) {
                EmptyView()
            }

            VStack(alignment: .leading, spacing: 11) {
                Text("Share with")
                    .font(Font.custom("SF Pro Display", size: 28)
                        .weight(.bold))
                    .foregroundColor(Color(red: 0.82, green: 0.82, blue: 0.83))
                Text("This user will receive an invitation to join your ‘Family’ vault.")
                    .font(Font.custom("SF Pro Text", size: 14))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.58))
            }

            TextField("Proton email address", text: $viewModel.email)
                .font(Font.custom("SF Pro Display", size: 22))
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .foregroundColor(PassColor.textNorm.toColor)
                .focused($defaultFocus, equals: true)

            Spacer()
        }
        .onAppear {
            defaultFocus = true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(kItemDetailSectionPadding)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: PassColor.backgroundNorm))
        .toolbar { toolbarContent }
        .ignoresSafeArea(.keyboard)
        .navigationModifier()
    }
}

private extension UserEmailView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: IconProvider.cross,
                         iconColor: PassColor.interactionNormMajor2,
                         backgroundColor: PassColor.interactionNormMinor1,
                         action: dismiss.callAsFunction)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            DisablableCapsuleTextButton(title: "Continue",
                                        titleColor: PassColor.textInvert,
                                        disableTitleColor: PassColor.textHint,
                                        backgroundColor: PassColor.interactionNormMajor1,
                                        disableBackgroundColor: PassColor.interactionNormMinor1,
                                        disabled: false, //! viewModel.canContinue,
                                        action: { isShowingDetailView = true })
        }
    }
}

struct UserEmailView_Previews: PreviewProvider {
    static var previews: some View {
        UserEmailView()
    }
}
