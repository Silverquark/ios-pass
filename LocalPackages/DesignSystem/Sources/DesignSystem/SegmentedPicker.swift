//
// SegmentedPicker.swift
// Proton Pass - Created on 15/12/2023.
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

import SwiftUI

public struct SegmentedPicker: View {
    @Binding var selectedIndex: Int
    let options: [String]

    public init(selectedIndex: Binding<Int>, options: [String]) {
        _selectedIndex = selectedIndex
        self.options = options
    }

    public var body: some View {
        ZStack {
            GeometryReader { proxy in
                let thumbWidth = proxy.size.width / CGFloat(options.count)
                PassColor.interactionNormMajor1.toColor
                    .clipShape(Capsule())
                    .frame(width: thumbWidth)
                    .offset(x: thumbWidth * CGFloat(selectedIndex))
                    .animation(.default, value: selectedIndex)
            }

            HStack {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    Button(action: {
                        selectedIndex = index
                    }, label: {
                        Text(option)
                            .font(.body.weight(.medium))
                            .foregroundStyle(PassColor.textNorm.toColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                    })
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(5)
        .background(PassColor.interactionNormMinor1.toColor)
        .clipShape(Capsule())
        .frame(height: 50)
    }
}
