//
// SearchView.swift
// Proton Pass - Created on 09/08/2022.
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
import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            ZStack {
                switch viewModel.state {
                case .clean:
                    CleanSearchView()

                case .initializing:
                    ProgressView()

                case .searching:
                    SearchingView()

                case .results:
                    if viewModel.results.isEmpty {
                        NoSearchResultView()
                    } else {
                        resultsList
                    }

                case .error(let error):
                    Text(error.messageForTheUser)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: viewModel.state)
            .toolbar { toolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            SwiftUISearchBar(onSearch: viewModel.search,
                             onCancel: dismiss.callAsFunction)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    private var resultsList: some View {
        List {
            ForEach(viewModel.results, id: \.itemId) { result in
                ItemSearchResultView(result: result,
                                     action: {},
                                     trailingView: { trailingView(for: result) })
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.results.count)
    }

    private func trailingView(for item: ItemSearchResult) -> some View {
        Menu(content: {
            switch item.type {
            case .login:
                CopyMenuButton(title: "Copy username",
                               action: { viewModel.copyUsername(item) })

                CopyMenuButton(title: "Copy password",
                               action: { viewModel.copyPassword(item) })

            case .alias:
                CopyMenuButton(title: "Copy email address",
                               action: { viewModel.copyEmailAddress(item) })
            case .note:
                if item.detail.first?.fullText.isEmpty == false {
                    CopyMenuButton(title: "Copy note",
                                   action: { viewModel.copyNote(item) })
                }
            }

            EditMenuButton {
                viewModel.editItem(item)
            }

            Divider()

            DestructiveButton(
                title: "Move to Trash",
                icon: IconProvider.trash,
                action: {
//                    selectedItem = item
//                    isShowingTrashingAlert.toggle()
                })
        }, label: {
            Image(uiImage: IconProvider.threeDotsHorizontal)
                .foregroundColor(.secondary)
        })
    }
}

private struct CleanSearchView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(uiImage: PassIcon.magnifyingGlass)
            Text("Search")
                .font(.title3)
                .fontWeight(.bold)
            Text("Search for alias, login or note easily.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 100)
        .padding(.horizontal)
    }
}

private struct SearchingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Spacer()
        }
        .padding(.top, 32)
        .padding(.horizontal)
    }
}

private struct NoSearchResultView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(uiImage: PassIcon.magnifyingGlassOnPaper)
            Text("No results found")
                .font(.title3)
                .fontWeight(.bold)
            Text("Try a different search term.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 100)
        .padding(.horizontal)
    }
}
