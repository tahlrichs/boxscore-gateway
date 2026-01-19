//
//  TableModels.swift
//  BoxScore
//
//  Generic table models for box score display
//

import Foundation
import SwiftUI

// MARK: - Table Column

struct TableColumn: Identifiable, Codable, @unchecked Sendable {
    let id: String
    let title: String
    let width: CGFloat
    var alignment: HorizontalAlignment = .center
    
    init(id: String, title: String, width: CGFloat = 44, alignment: HorizontalAlignment = .center) {
        self.id = id
        self.title = title
        self.width = width
        self.alignment = alignment
    }
    
    // Custom Codable - alignment is not encoded (always center on decode)
    enum CodingKeys: String, CodingKey {
        case id, title, width
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        width = try container.decode(CGFloat.self, forKey: .width)
        alignment = .center
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(width, forKey: .width)
    }
}

// MARK: - Table Row

struct TableRow: Identifiable, Codable, @unchecked Sendable {
    let id: String
    let isTeamTotals: Bool
    let isHeader: Bool
    let leadingText: String      // Player name/number or "TEAM"
    let subtitle: String?        // Optional secondary text (e.g., position)
    let cells: [String]          // Pre-formatted stat strings
    var highlightColor: Color? = nil  // Optional row highlight (not encoded)
    
    init(
        id: String,
        isTeamTotals: Bool = false,
        isHeader: Bool = false,
        leadingText: String,
        subtitle: String? = nil,
        cells: [String],
        highlightColor: Color? = nil
    ) {
        self.id = id
        self.isTeamTotals = isTeamTotals
        self.isHeader = isHeader
        self.leadingText = leadingText
        self.subtitle = subtitle
        self.cells = cells
        self.highlightColor = highlightColor
    }
    
    // Custom Codable - highlightColor is not encoded
    enum CodingKeys: String, CodingKey {
        case id, isTeamTotals, isHeader, leadingText, subtitle, cells
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isTeamTotals = try container.decodeIfPresent(Bool.self, forKey: .isTeamTotals) ?? false
        isHeader = try container.decodeIfPresent(Bool.self, forKey: .isHeader) ?? false
        leadingText = try container.decode(String.self, forKey: .leadingText)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        cells = try container.decode([String].self, forKey: .cells)
        highlightColor = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isTeamTotals, forKey: .isTeamTotals)
        try container.encode(isHeader, forKey: .isHeader)
        try container.encode(leadingText, forKey: .leadingText)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encode(cells, forKey: .cells)
    }
}

// MARK: - Table Section

/// A section of rows with an optional title (e.g., "Starters", "Bench")
struct TableSection: Identifiable {
    let id: String
    let title: String?
    let rows: [TableRow]
    let teamTotalsRow: TableRow?
    
    init(id: String, title: String? = nil, rows: [TableRow], teamTotalsRow: TableRow? = nil) {
        self.id = id
        self.title = title
        self.rows = rows
        self.teamTotalsRow = teamTotalsRow
    }
}

// MARK: - Empty State

struct EmptyTableState {
    let message: String
    
    static func noData(for section: String) -> EmptyTableState {
        EmptyTableState(message: "No \(section)")
    }
}

