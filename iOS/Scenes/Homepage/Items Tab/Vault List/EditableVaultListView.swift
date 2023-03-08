//
// EditableVaultListView.swift
// Proton Pass - Created on 08/03/2023.
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

import SwiftUI
import UIComponents

struct EditableVaultListView: View {
    @StateObject var viewModel: EditableVaultListViewModel

    var body: some View {
        VStack(alignment: .leading) {
            NotchView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 5)
            ScrollView {
                VStack {
                    switch viewModel.vaultsManager.state {
                    case .loading, .error:
                        // Should never happen
                        ProgressView()
                    case .loaded(let vaults):
                        let allItemCount = vaults.map { $0.items.count }.reduce(0) { $0 + $1 }
                        HStack {
                            VStack {
                                Text("All vaults")
                                Text("\(allItemCount) items")
                            }

                            Spacer()

                            if viewModel.vaultsManager.selectedVault == nil {
                                Label("", systemImage: "checkmark")
                                    .foregroundColor(.passBrand)
                            }
                        }

                        ForEach(vaults, id: \.hashValue) { vault in
                            HStack {
                                VStack {
                                    Text(vault.vault.name)
                                    Text("\(vault.items.count) items")
                                }
                            }
                        }

                        VStack {
                            Text("Trash")
                            Text("0 items")
                        }
                    }
                }
                .padding(.horizontal)
            }

            HStack {
                CapsuleTextButton(title: "Create vault",
                                  titleColor: .passBrand,
                                  backgroundColor: .passBrand.withAlphaComponent(0.08),
                                  disabled: false,
                                  action: viewModel.createNewVault)
                Spacer()
            }
            .padding(.horizontal)
        }
        .background(Color.passSecondaryBackground)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
