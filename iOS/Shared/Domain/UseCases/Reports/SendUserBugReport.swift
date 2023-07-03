//
// SendUserBugReport.swift
// Proton Pass - Created on 03/07/2023.
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

import Foundation

protocol SendUserBugReportUseCase: Sendable {
    func execute(with title: String, and description: String) async throws -> Bool
}

extension SendUserBugReportUseCase {
    func callAsFunction(with title: String, and description: String) async throws -> Bool {
        try await execute(with: title, and: description)
    }
}

final class SendUserBugReport: SendUserBugReportUseCase {
    private let reportRepository: ReportRepositoryProtocol
    private let extractLogsToFile: ExtractLogsToFileUseCase
    private let getLogEntries: GetLogEntriesUseCase

    init(reportRepository: ReportRepositoryProtocol,
         extractLogsToFile: ExtractLogsToFileUseCase,
         getLogEntries: GetLogEntriesUseCase) {
        self.reportRepository = reportRepository
        self.extractLogsToFile = extractLogsToFile
        self.getLogEntries = getLogEntries
    }

    func execute(with title: String, and description: String) async throws -> Bool {
        let entries = try? await getLogEntries(for: .hostApp)
        var logs: [String: URL]?
        if let entries,
           let logFileUrl = try? await extractLogsToFile(for: entries.reversed().prefix(500).toArray,
                                                         in: "temporaryLogs.log") {
            logs = ["File0": logFileUrl]
        }
        return try await reportRepository.sendBug(with: title, and: description, optional: logs)
    }
}
