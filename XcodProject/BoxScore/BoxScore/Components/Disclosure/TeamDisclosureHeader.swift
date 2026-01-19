//
//  TeamDisclosureHeader.swift
//  BoxScore
//
//  Reusable disclosure header for expandable sections
//

import SwiftUI

struct TeamDisclosureHeader: View {
    let title: String
    let isExpanded: Bool
    let level: DisclosureLevel
    let onToggle: () -> Void
    
    enum DisclosureLevel {
        case group   // e.g., "Offense", "Defense"
        case section // e.g., "Passing", "Rushing"
        
        var backgroundColor: Color {
            switch self {
            case .group: return Color(.systemGray5)
            case .section: return Color(.systemGray6)
            }
        }
        
        var font: Font {
            switch self {
            case .group: return .subheadline
            case .section: return .caption
            }
        }
        
        var fontWeight: Font.Weight {
            switch self {
            case .group: return .semibold
            case .section: return .medium
            }
        }
        
        var paddingLeading: CGFloat {
            switch self {
            case .group: return 12
            case .section: return 24
            }
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: level == .group ? 12 : 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                
                Text(title)
                    .font(level.font)
                    .fontWeight(level.fontWeight)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.leading, level.paddingLeading)
            .padding(.trailing, 12)
            .padding(.vertical, level == .group ? 10 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(level.backgroundColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Title (non-expandable)

struct SectionTitleView: View {
    let title: String
    let level: TeamDisclosureHeader.DisclosureLevel
    
    var body: some View {
        HStack {
            Text(title)
                .font(level.font)
                .fontWeight(level.fontWeight)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.leading, level.paddingLeading)
        .padding(.trailing, 12)
        .padding(.vertical, level == .group ? 10 : 8)
        .background(level.backgroundColor)
    }
}

#Preview {
    VStack(spacing: 0) {
        TeamDisclosureHeader(
            title: "Offense",
            isExpanded: true,
            level: .group
        ) {}
        
        TeamDisclosureHeader(
            title: "Passing",
            isExpanded: true,
            level: .section
        ) {}
        
        TeamDisclosureHeader(
            title: "Rushing",
            isExpanded: false,
            level: .section
        ) {}
        
        TeamDisclosureHeader(
            title: "Defense",
            isExpanded: false,
            level: .group
        ) {}
    }
}

