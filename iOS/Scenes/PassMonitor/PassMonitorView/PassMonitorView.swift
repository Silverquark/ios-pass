//
//
// PassMonitorView.swift
// Proton Pass - Created on 29/02/2024.
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
import Factory
import Macro
import ProtonCoreUIFoundations
import SwiftUI

enum SecureRowType {
    case info, warning, danger, success, upsell

    var icon: String? {
        switch self {
        case .danger:
            "exclamationmark.circle.fill"
        case .warning:
            "exclamationmark.square.fill"
        case .success:
            "checkmark.square.fill"
        default:
            nil
        }
    }

    var iconColor: UIColor {
        switch self {
        case .danger:
            PassColor.passwordInteractionNormMajor1
        case .warning:
            PassColor.noteInteractionNormMajor1
        case .success:
            PassColor.cardInteractionNormMajor1
        default:
            PassColor.loginInteractionNormMajor1
        }
    }

    /// Icon used in item detail pages
    var detailIcon: String? {
        switch self {
        case .info:
            "exclamationmark.square.fill"
        default:
            icon
        }
    }

    var background: UIColor {
        switch self {
        case .danger:
            PassColor.passwordInteractionNormMinor2
        case .warning:
            PassColor.noteInteractionNormMinor2
        case .success:
            PassColor.cardInteractionNormMinor2
        case .info:
            PassColor.inputBackgroundNorm
        case .upsell:
            PassColor.interactionNormMinor2
        }
    }

    /// Background used in item detail pages
    var detailBackground: UIColor {
        switch self {
        case .info:
            PassColor.loginInteractionNormMinor2
        default:
            background
        }
    }

    var border: UIColor {
        switch self {
        case .danger:
            PassColor.passwordInteractionNormMinor1
        case .warning:
            PassColor.noteInteractionNormMinor1
        case .success:
            PassColor.cardInteractionNormMinor1
        case .info:
            PassColor.inputBorderNorm
        case .upsell:
            PassColor.interactionNormMinor1
        }
    }

    var infoForeground: UIColor {
        switch self {
        case .danger:
            PassColor.passwordInteractionNormMajor2
        case .warning:
            PassColor.noteInteractionNormMajor2
        case .info, .success, .upsell:
            PassColor.textNorm
        }
    }

    var infoBackground: UIColor {
        switch self {
        case .danger:
            PassColor.passwordInteractionNormMinor1
        case .warning:
            PassColor.noteInteractionNormMinor1
        case .success:
            PassColor.cardInteractionNormMinor1
        case .info, .upsell:
            PassColor.backgroundMedium
        }
    }

    var titleColor: UIColor {
        switch self {
        case .danger:
            PassColor.passwordInteractionNormMajor2
        default:
            PassColor.textNorm
        }
    }

    var subtitleColor: UIColor {
        switch self {
        case .success:
            PassColor.cardInteractionNormMajor2
        case .danger:
            PassColor.passwordInteractionNormMajor2
        default:
            PassColor.textWeak
        }
    }
}

struct PassMonitorView: View {
    @StateObject var viewModel: PassMonitorViewModel

    private enum ElementSizes {
        static let cellHeight: CGFloat = 75
    }

    var body: some View {
        mainContent
            .animation(.default, value: viewModel.weaknessStats)
            .navigationTitle("Pass Monitor")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollViewEmbeded(maxWidth: .infinity)
            .background(PassColor.backgroundNorm.toColor)
            .animation(.default, value: viewModel.breaches)
            .animation(.default, value: viewModel.weaknessStats)
            .showSpinner(viewModel.updatingSentinel)
            .sheet(isPresented: $viewModel.showSentinelSheet) {
                if #available(iOS 16.4, *) {
                    sentinelSheet(noBackgroundSheet: true)
                        .presentationBackground(.clear)
                        .padding(.horizontal)
                } else {
                    sentinelSheet(noBackgroundSheet: false)
                }
            }
            .refreshable {
                try? await viewModel.refresh()
            }
            .navigationStackEmbeded()
            .task {
                try? await viewModel.refresh()
            }
    }
}

private extension PassMonitorView {
    var mainContent: some View {
        LazyVStack(spacing: DesignConstant.sectionPadding) {
            if let breaches = viewModel.breaches {
                breachedDataRows(breaches: breaches)
            }

            if let weaknessStats = viewModel.weaknessStats {
                if viewModel.isFreeUser {
                    passMonitorRow(rowType: .upsell,
                                   title: "Proton Sentinel",
                                   subTitle: "Advanced account protection program",
                                   badge: true,
                                   action: { viewModel.showSentinelSheet = true })
                } else {
                    sentinelRow(rowType: .info,
                                title: "Proton Sentinel",
                                subTitle: "Advanced account protection program",
                                action: { viewModel.showSentinelSheet = true })
                }
                Section {
                    VStack(spacing: DesignConstant.sectionPadding) {
                        weakPasswordsRow(weaknessStats.weakPasswords)
                        reusedPasswordsRow(weaknessStats.reusedPasswords)
                        missing2FARow(weaknessStats.missing2FA)
                            .padding(.top, 16)
                        excludedItemsRow(weaknessStats.excludedItems)
                    }
                } header: {
                    HStack {
                        Text("Passwords Health")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(PassColor.textNorm.toColor)
                        Spacer()
                    }.padding(.top, DesignConstant.sectionPadding)
                }
            }
        }
        .padding(DesignConstant.sectionPadding)
    }

    func sentinelSheet(noBackgroundSheet: Bool) -> some View {
        SentinelSheetView(isPresented: $viewModel.showSentinelSheet,
                          noBackgroundSheet: noBackgroundSheet,
                          sentinelActive: viewModel.isSentinelActive,
                          mainAction: { viewModel.sentinelSheetAction() },
                          secondaryAction: { viewModel.showSentinelInformation() })
            .presentationDetents([.height(520)])
    }

    var passPlusBadge: some View {
        Image(uiImage: PassIcon.passSubscriptionBadge)
            .resizable()
            .scaledToFit()
            .frame(height: 24)
    }
}

private extension PassMonitorView {
    @ViewBuilder
    func breachedDataRows(breaches: UserBreaches) -> some View {
        if viewModel.isFreeUser {
            upsellRow(breaches: breaches)
        } else {
            breachedRow(breaches)
        }
    }

    func sentinelRow(rowType: SecureRowType,
                     title: String,
                     subTitle: String?,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(PassColor.textNorm.toColor)
                    if let subTitle {
                        Text(subTitle)
                            .font(.footnote)
                            .foregroundColor(PassColor.textWeak.toColor)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, minHeight: ElementSizes.cellHeight, alignment: .leading)
                .layoutPriority(1)

                StaticToggle(isOn: viewModel.isSentinelActive, action: action)
            }
            .padding(.horizontal, DesignConstant.sectionPadding)
            .roundedDetailSection(backgroundColor: rowType.background,
                                  borderColor: rowType.border)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func upsellRow(breaches: UserBreaches) -> some View {
        let isBreached = viewModel.isBreached
        ZStack(alignment: .topTrailing) {
            VStack(alignment: isBreached ? .leading : .center, spacing: DesignConstant.sectionPadding) {
                Text(isBreached ? "Breached Detected" : "Dark Web Monitoring")
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundStyle(isBreached ? PassColor.passwordInteractionNormMajor2
                        .toColor : PassColor.textNorm.toColor)
                    .padding(.top, DesignConstant.sectionPadding + 15)
                    .multilineTextAlignment(isBreached ? .leading : .center)

                Text(isBreached ? "Your email address was leaked in at least 1 data breach." :
                    "Get notified if your email, password or other personal data was leaked.")
                    .font(.body)
                    .foregroundStyle(isBreached ? PassColor.passwordInteractionNormMajor2
                        .toColor : PassColor.textNorm.toColor)
                    .multilineTextAlignment(isBreached ? .leading : .center)

                if isBreached, let latestBreach = viewModel.latestBreachInfo {
                    HStack {
                        Image(uiImage: PassIcon.lightning)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                            .padding(10)
                            .roundedDetailSection(backgroundColor: PassColor
                                .passwordInteractionNormMinor1,
                                borderColor: .clear)

                        VStack(alignment: .leading) {
                            Text(latestBreach.domain)
                                .font(.body)
                                .foregroundStyle(PassColor.textNorm.toColor)
                            Text(latestBreach.date)
                                .font(.footnote)
                                .foregroundStyle(PassColor.textWeak.toColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignConstant.sectionPadding) {
                        VStack(alignment: .leading) {
                            Text("Email address")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundStyle(PassColor.passwordInteractionNormMajor2.toColor)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(verbatim: "Thisisafakeemail@proton.me")
                                .font(.body)
                                .foregroundStyle(PassColor.passwordInteractionNormMajor2.toColor)
                                .blur(radius: 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DesignConstant.sectionPadding)

                        VStack(alignment: .leading) {
                            Text("Password")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundStyle(PassColor.passwordInteractionNormMajor2.toColor)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(verbatim: "Thisisafakepassword")
                                .font(.body)
                                .foregroundStyle(PassColor.passwordInteractionNormMajor2.toColor)
                                .blur(radius: 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, DesignConstant.sectionPadding)
                    }
                    .padding(DesignConstant.sectionPadding)
                    .frame(maxWidth: .infinity)
                    .roundedDetailSection(backgroundColor: PassColor
                        .passwordInteractionNormMinor1,
                        borderColor: .clear)
                }

                CapsuleTextButton(title: isBreached ? "View Details" : "Enable",
                                  titleColor: PassColor.textInvert,
                                  backgroundColor: isBreached ? PassColor
                                      .passwordInteractionNormMajor2 : PassColor.interactionNormMajor2,
                                  action: { viewModel.upsell(entryPoint: .darkWebMonitorNoBreach) })
                    .padding(.bottom, DesignConstant.sectionPadding)
            }
            passPlusBadge
                .padding(.top, 10)
        }
        .padding(.horizontal, DesignConstant.sectionPadding)
        .roundedDetailSection(backgroundColor: breaches.breached ? PassColor
            .passwordInteractionNormMinor2 : PassColor.interactionNormMinor2,
            borderColor: breaches.breached ? PassColor.passwordInteractionNormMinor1 : PassColor
                .interactionNormMinor1)
    }

    func breachedRow(_ breaches: UserBreaches) -> some View {
        passMonitorRow(rowType: viewModel.numberOfBreaches > 0 ? .danger : .success,
                       title: "Dark Web Monitoring",
                       subTitle: viewModel.numberOfBreaches > 0 ?
                           "\(viewModel.numberOfBreaches) breaches detected" :
                           "No breaches detected",
                       info: viewModel.numberOfBreaches > 0 ? "\(viewModel.numberOfBreaches)" : nil,
                       action: { viewModel.showSecurityWeakness(type: .breaches(breaches)) })
    }
}

private extension PassMonitorView {
    func weakPasswordsRow(_ weakPasswords: Int) -> some View {
        passMonitorRow(rowType: weakPasswords > 0 ? .warning : .success,
                       title: "Weak Passwords",
                       subTitle: "Change your passwords",
                       info: "\(weakPasswords)",
                       action: { viewModel.showSecurityWeakness(type: .weakPasswords) })
    }
}

private extension PassMonitorView {
    func reusedPasswordsRow(_ reusedPasswords: Int) -> some View {
        passMonitorRow(rowType: reusedPasswords > 0 ? .warning : .success,
                       title: "Reused passwords",
                       subTitle: "Generate unique passwords",
                       info: "\(reusedPasswords)",
                       action: { viewModel.showSecurityWeakness(type: .reusedPasswords) })
    }
}

private extension PassMonitorView {
    func missing2FARow(_ missing2FA: Int) -> some View {
        passMonitorRow(rowType: .info,
                       title: "Inactive 2FA",
                       subTitle: "Set up 2FA for more security",
                       info: "\(missing2FA)",
                       action: { viewModel.showSecurityWeakness(type: .missing2FA) })
    }
}

private extension PassMonitorView {
    func excludedItemsRow(_ excludedItems: Int) -> some View {
        passMonitorRow(rowType: .info,
                       title: "Excluded items",
                       subTitle: "These items remain at risk",
                       info: "\(excludedItems)",
                       action: { viewModel.showSecurityWeakness(type: .excludedItems) })
    }
}

// MARK: - Rows

private extension PassMonitorView {
    func passMonitorRow(rowType: SecureRowType,
                        title: LocalizedStringKey,
                        subTitle: LocalizedStringKey?,
                        info: String? = nil,
                        badge: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignConstant.sectionPadding) {
                if let iconName = rowType.icon {
                    Image(systemName: iconName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundColor(rowType.iconColor.toColor)
                        .frame(width: DesignConstant.Icons.defaultIconSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 4) {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(rowType.titleColor.toColor)
                        .minimumScaleFactor(0.5)

                    if let subTitle {
                        Text(subTitle)
                            .font(.callout)
                            .lineLimit(1)
                            .foregroundColor(rowType.subtitleColor.toColor)
                            .layoutPriority(1)
                            .minimumScaleFactor(0.25)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: ElementSizes.cellHeight, alignment: .leading)
                .contentShape(Rectangle())

                if let info {
                    Text(info)
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 11)
                        .foregroundColor(rowType.infoForeground.toColor)
                        .background(rowType.infoBackground.toColor)
                        .clipShape(Capsule())
                }

                if badge {
                    passPlusBadge
                } else {
                    ItemDetailSectionIcon(icon: IconProvider.chevronRight,
                                          color: rowType.infoForeground,
                                          width: 12)
                }
            }
            .padding(.horizontal, DesignConstant.sectionPadding)
            .roundedDetailSection(backgroundColor: rowType.background,
                                  borderColor: rowType.border)
        }
        .buttonStyle(.plain)
    }
}
