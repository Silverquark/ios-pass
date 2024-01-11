//
//
// ItemHistoryView.swift
// Proton Pass - Created on 09/01/2024.
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

import DesignSystem
import Entities
import ProtonCoreUIFoundations
import SwiftUI

struct ItemHistoryView: View {
    @StateObject var viewModel: ItemHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    private enum ElementSizes {
        static let circleSize: CGFloat = 15
        static let line: CGFloat = 1
        static let cellHeight: CGFloat = 75

        static var minSpacerSize: CGFloat {
            (ElementSizes.cellHeight - ElementSizes.circleSize) / 2
        }
    }

    var body: some View {
        mainContainer
            .task {
                await viewModel.loadItemHistory()
            }
    }
}

private extension ItemHistoryView {
    var mainContainer: some View {
        VStack(alignment: .leading) {
            Text("History")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(PassColor.textNorm.toColor)
                .padding(.horizontal, DesignConstant.sectionPadding)

            if let lastUsed = viewModel.lastUsedTime {
                header(lastUsed: lastUsed)
            }
            if viewModel.state == .loading {
                progressView
            } else if !viewModel.state.history.isEmpty {
                historyListView
            }
        }
        .animation(.default, value: viewModel.state)
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PassColor.backgroundNorm.toColor)
        .toolbar { toolbarContent }
        .routingProvided
        .navigationStackEmbeded($path)
    }
}

private extension ItemHistoryView {
    func header(lastUsed: String) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: DesignConstant.sectionPadding) {
                ItemDetailSectionIcon(icon: IconProvider.magicWand,
                                      color: PassColor.textWeak)

                VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 4) {
                    Text("Last autofill")
                        .font(.body)
                        .foregroundStyle(PassColor.textNorm.toColor)
                    Text(lastUsed)
                        .font(.footnote)
                        .foregroundColor(PassColor.textWeak.toColor)
                }
                .contentShape(Rectangle())
            }
            .padding(.bottom, 20)

            Text("Changelog")
                .font(.body)
                .foregroundStyle(PassColor.textNorm.toColor)
        }
        .padding(.horizontal, DesignConstant.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private extension ItemHistoryView {
    var progressView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private extension ItemHistoryView {
    var historyListView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.state.history, id: \.item.revision) { item in
                if viewModel.isCreationRevision(item) {
                    navigationLink(for: item, view: creationCell(item: item))
//                    NavigationLink(value: GeneralRouterDestination
//                        .historyDetail(currentItem: viewModel.item, revision: item),
//
//                        label: {
//                            creationCell(item: item)
//                        })
//                        .isDetailLink(false)
//                        .buttonStyle(.plain)
                } else if viewModel.isCurrentRevision(item) {
                    navigationLink(for: item, view: currentCell(item: item))

                } else {
                    navigationLink(for: item, view: modificationCell(item: item))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignConstant.sectionPadding)
        .scrollViewEmbeded(maxWidth: .infinity)
    }

    func creationCell(item: ItemContent) -> some View {
        HStack {
            VStack(spacing: 0) {
                verticalLine

                Circle()
                    .background(Circle().foregroundColor(PassColor.textWeak.toColor))
                    .frame(width: ElementSizes.circleSize, height: ElementSizes.circleSize)

                Spacer(minLength: ElementSizes.minSpacerSize)
            }
            infoRow(title: "Created", infos: item.creationDate, icon: IconProvider.bolt)
                .padding(.top, 8)
        }
    }

    func currentCell(item: ItemContent) -> some View {
        HStack {
            VStack(spacing: 0) {
                Spacer(minLength: ElementSizes.minSpacerSize)

                Circle()
                    .strokeBorder(PassColor.textWeak.toColor, lineWidth: 1)
                    .frame(width: ElementSizes.circleSize, height: ElementSizes.circleSize)

                verticalLine
            }
            infoRow(title: "Current",
                    infos: nil,
                    icon: IconProvider.clock,
                    shouldDisplay: false)
                .padding(.bottom, 8)
        }
    }

    func modificationCell(item: ItemContent) -> some View {
        HStack {
            VStack(spacing: 0) {
                verticalLine

                Circle()
                    .background(Circle().foregroundColor(PassColor.textWeak.toColor))
                    .frame(width: ElementSizes.circleSize, height: ElementSizes.circleSize)

                verticalLine
            }
            infoRow(title: "Modified", infos: item.revisionDate, icon: IconProvider.pencil)
                .padding(.vertical, 8)
        }
    }

    func navigationLink(for item: ItemContent, view: some View) -> some View {
        NavigationLink(value: GeneralRouterDestination
            .historyDetail(currentItem: viewModel.item, revision: item),
            label: {
                view
            })
            .isDetailLink(false)
            .buttonStyle(.plain)
    }
}

private extension ItemHistoryView {
    func infoRow(title: LocalizedStringKey,
                 infos: String?,
                 icon: UIImage,
                 shouldDisplay: Bool = true) -> some View {
        HStack(spacing: DesignConstant.sectionPadding) {
            ItemDetailSectionIcon(icon: icon,
                                  color: PassColor.textWeak)

            VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(PassColor.textNorm.toColor)
                if let infos {
                    Text(infos)
                        .font(.footnote)
                        .foregroundColor(PassColor.textWeak.toColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: ElementSizes.cellHeight, alignment: .leading)
            .contentShape(Rectangle())
            if shouldDisplay {
                ItemDetailSectionIcon(icon: IconProvider.chevronRight,
                                      color: PassColor.textWeak)
            }
        }
        .padding(.horizontal, DesignConstant.sectionPadding)
        .roundedDetailSection()
    }
}

private extension ItemHistoryView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: IconProvider.chevronDown,
                         iconColor: PassColor.interactionNormMajor2,
                         backgroundColor: PassColor.interactionNormMinor1) {
                dismiss()
            }
        }
    }
}

// MARK: - UIElements

private extension ItemHistoryView {
    var verticalLine: some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(maxWidth: ElementSizes.line, maxHeight: .infinity)
            .background(PassColor.textWeak.toColor)
    }
}

//
//    .navigate(isActive: $viewModel.goToNextStep,
//              destination: router.navigate(to: .userSharePermission))

//
// struct ItemHistoryView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemHistoryView()
//    }
// }

// struct UserEmailView: View {
//    @Environment(\.dismiss) private var dismiss
//    @StateObject private var viewModel = UserEmailViewModel()
//    private var router = resolve(\RouterContainer.mainNavViewRouter)
//    @State private var isFocused = false
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("Share with")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//                .foregroundColor(PassColor.textNorm.toColor)
//                .padding(.horizontal, DesignConstant.sectionPadding)
//
//            VStack(alignment: .leading) {
//                if case let .new(vault, _) = viewModel.vault {
//                    vaultRow(vault)
//                }
//
//                FlowLayout(mode: .scrollable,
//                           items: viewModel.selectedEmails + [""],
//                           viewMapping: { token(for: $0) })
//                    .padding(.leading, -4)
//
//                PassDivider()
//                    .padding(.horizontal, -DesignConstant.sectionPadding)
//                    .padding(.top, 16)
//                    .padding(.bottom, 24)
//
//                if viewModel.recommendationsState == .loading {
//                    VStack {
//                        Spacer(minLength: 50)
//                        ProgressView()
//                    }
//                    .frame(maxWidth: .infinity, alignment: .center)
//                } else if let recommendations = viewModel.recommendationsState.recommendations,
//                          !recommendations.isEmpty {
//                    InviteSuggestionsSection(selectedEmails: $viewModel.selectedEmails,
//                                             recommendations: recommendations)
//                }
//
//                Spacer()
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.horizontal, DesignConstant.sectionPadding)
//            .scrollViewEmbeded(maxWidth: .infinity)
//        }
//        .onAppear {
//            isFocused = true
//        }
//        .onChange(of: viewModel.highlightedEmail) { highlightedEmail in
//            isFocused = highlightedEmail == nil
//        }
//        .animation(.default, value: viewModel.selectedEmails)
//        .animation(.default, value: viewModel.recommendationsState)
//        .navigate(isActive: $viewModel.goToNextStep,
//                  destination: router.navigate(to: .userSharePermission))
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .navigationBarTitleDisplayMode(.inline)
//        .background(PassColor.backgroundNorm.toColor)
//        .toolbar { toolbarContent }
//        .navigationStackEmbeded()
//        .ignoresSafeArea(.keyboard)
//    }
// }
//
// private extension UserEmailView {
//    @ViewBuilder
//    func token(for email: String) -> some View {
//        if email.isEmpty {
//            emailTextField
//        } else {
//            emailCell(for: email)
//        }
//    }
//
//    var emailTextField: some View {
//        BackspaceAwareTextField(text: $viewModel.email,
//                                isFocused: $isFocused,
//                                config: .init(font: .body,
//                                              placeholder: #localized("Email address"),
//                                              autoCapitalization: .none,
//                                              autoCorrection: .no,
//                                              keyboardType: .emailAddress,
//                                              returnKeyType: .default,
//                                              textColor: PassColor.textNorm,
//                                              tintColor: PassColor.interactionNorm),
//                                onBackspace: { viewModel.highlightLastEmail() },
//                                onReturn: { viewModel.appendCurrentEmail() })
//            .frame(width: 150, height: 32)
//            .clipped()
//    }
//
//    @ViewBuilder
//    func emailCell(for email: String) -> some View {
//        let highlighted = viewModel.highlightedEmail == email
//        let focused: Binding<Bool> = .init(get: {
//            highlighted
//        }, set: { newValue in
//            if !newValue {
//                viewModel.highlightedEmail = nil
//            }
//        })
//
//        HStack(alignment: .center, spacing: 10) {
//            Text(email)
//        }
//        .font(.callout)
//        .foregroundColor(highlighted ? PassColor.textInvert.toColor : PassColor.textNorm.toColor)
//        .padding(.horizontal, 10)
//        .padding(.vertical, 8)
//        .background(highlighted ?
//            PassColor.interactionNormMajor2.toColor : PassColor.interactionNormMinor1.toColor)
//        .cornerRadius(9)
//        .animation(.default, value: highlighted)
//        .contentShape(Rectangle())
//        .onTapGesture { viewModel.toggleHighlight(email) }
//        .overlay {
//            // Dummy invisible text field to allow removing a token with backspace
//            BackspaceAwareTextField(text: .constant(""),
//                                    isFocused: focused,
//                                    config: .init(font: .title,
//                                                  placeholder: "",
//                                                  autoCapitalization: .none,
//                                                  autoCorrection: .no,
//                                                  keyboardType: .emailAddress,
//                                                  returnKeyType: .default,
//                                                  textColor: .clear,
//                                                  tintColor: .clear),
//                                    onBackspace: { viewModel.deselect(email) },
//                                    onReturn: { viewModel.toggleHighlight(email) })
//                .opacity(0)
//        }
//    }
// }
//
// private extension UserEmailView {
//    func vaultRow(_ vault: VaultProtobuf) -> some View {
//        HStack(spacing: 16) {
//            VaultRow(thumbnail: {
//                         CircleButton(icon: vault.display.icon.icon.bigImage,
//                                      iconColor: vault.display.color.color.color,
//                                      backgroundColor: vault.display.color.color.color
//                                          .withAlphaComponent(0.16))
//                     },
//                     title: vault.name,
//                     itemCount: 1,
//                     isShared: false,
//                     isSelected: false,
//                     maxWidth: nil,
//                     height: 74)
//
//            CircleButton(icon: IconProvider.pencil,
//                         iconColor: PassColor.interactionNormMajor2,
//                         backgroundColor: PassColor.interactionNormMinor1,
//                         action: { viewModel.customizeVault() })
//        }
//        .padding(.horizontal, 16)
//        .roundedEditableSection()
//    }
// }

// private extension UserEmailView {
//    @ToolbarContentBuilder
//    var toolbarContent: some ToolbarContent {
//        ToolbarItem(placement: .navigationBarLeading) {
//            CircleButton(icon: IconProvider.cross,
//                         iconColor: PassColor.interactionNormMajor2,
//                         backgroundColor: PassColor.interactionNormMinor1) {
//                viewModel.resetShareInviteInformation()
//                dismiss()
//            }
//        }
//
//        ToolbarItem(placement: .navigationBarTrailing) {
//            if viewModel.isChecking {
//                ProgressView()
//            } else {
//                DisablableCapsuleTextButton(title: #localized("Continue"),
//                                            titleColor: PassColor.textInvert,
//                                            disableTitleColor: PassColor.textHint,
//                                            backgroundColor: PassColor.interactionNormMajor1,
//                                            disableBackgroundColor: PassColor.interactionNormMinor1,
//                                            disabled: !viewModel.canContinue,
//                                            action: { viewModel.continue() })
//            }
//        }
//    }
// }
