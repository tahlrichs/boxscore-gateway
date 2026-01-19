//
//  GolfModels.swift
//  BoxScore
//
//  Golf-specific data models for tournaments and leaderboards
//

import Foundation

// MARK: - Golfer Stats

struct GolferStats: Codable, Sendable, Equatable {
    let position: Int
    let score: String           // e.g., "-12" or "E" or "+3"
    let toParTotal: Int         // numeric for sorting
    let rounds: [String]        // ["68", "70", "69", "72"] or ["-4", "-2", "-3", "E"]
    let thru: String            // "F" for finished, "12" for holes played
    let today: String           // Today's score relative to par

    /// Display position with suffix (1st, 2nd, T3, etc.)
    var positionDisplay: String {
        if position <= 0 {
            return "-"
        }
        return "\(position)"
    }

    /// Score with color indication (negative is good)
    var scoreColor: ScoreColor {
        if toParTotal < 0 {
            return .underPar
        } else if toParTotal > 0 {
            return .overPar
        }
        return .even
    }

    enum ScoreColor {
        case underPar   // Red/Green (good)
        case even       // Black
        case overPar    // Blue/Red (bad)
    }
}

// MARK: - Golf Winner

struct GolfWinner: Codable, Sendable, Equatable {
    let name: String
    let score: String?
    let isDefendingChamp: Bool?

    /// Display name with defending champ indicator
    var displayText: String {
        if isDefendingChamp == true {
            return "Defending: \(name)"
        }
        if let score = score {
            return "\(name) (\(score))"
        }
        return name
    }

    /// Short display for card view
    var shortDisplayText: String {
        if isDefendingChamp == true {
            return "Def. Champion: \(shortName)"
        }
        if let score = score {
            return "Winner: \(shortName) (\(score))"
        }
        return "Winner: \(shortName)"
    }

    /// Shortened name (S. Scheffler format)
    private var shortName: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let firstName = parts[0]
            let lastName = parts.dropFirst().joined(separator: " ")
            return "\(firstName.prefix(1)). \(lastName)"
        }
        return name
    }
}

// MARK: - Golfer Line

struct GolferLine: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let name: String
    let country: String?
    let imageURL: URL?
    let stats: GolferStats?

    /// Short display name (S. Scheffler format)
    var displayName: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let firstName = parts[0]
            let lastName = parts.dropFirst().joined(separator: " ")
            return "\(firstName.prefix(1)). \(lastName)"
        }
        return name
    }

    /// Full name for detail views
    var fullName: String {
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, country, imageURL, stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        country = try container.decodeIfPresent(String.self, forKey: .country)

        // Handle URL decoding - can be string or URL
        if let urlString = try? container.decodeIfPresent(String.self, forKey: .imageURL) {
            imageURL = URL(string: urlString)
        } else {
            imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        }

        stats = try container.decodeIfPresent(GolferStats.self, forKey: .stats)
    }

    init(id: String, name: String, country: String? = nil, imageURL: URL? = nil, stats: GolferStats? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.imageURL = imageURL
        self.stats = stats
    }
}

// MARK: - Golf Tournament

struct GolfTournament: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let name: String
    let tour: String            // "pga" or "lpga"
    let venue: String
    let location: String
    let startDate: Date
    let endDate: Date
    let currentRound: Int       // 1, 2, 3, or 4
    let roundStatus: String     // "In Progress", "Complete", "Scheduled"
    let purse: String?          // "$8,400,000"
    let winner: GolfWinner?     // Winner for completed tournaments, or defending champ for scheduled
    let leaderboard: [GolferLine]

    /// Date range display (e.g., "Jan 15-18")
    var dateRangeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startStr = formatter.string(from: startDate)
        formatter.dateFormat = "d"
        let endStr = formatter.string(from: endDate)

        return "\(startStr)-\(endStr)"
    }

    /// Status display (e.g., "Round 2 In Progress")
    var statusDisplay: String {
        if roundStatus == "Complete" && currentRound >= 4 {
            return "Final"
        }
        return "Round \(currentRound) \(roundStatus)"
    }

    /// Top 3 golfers for collapsed card view
    var top3: [GolferLine] {
        Array(leaderboard.prefix(3))
    }

    /// Top 12 golfers for expanded card view
    var top12: [GolferLine] {
        Array(leaderboard.prefix(12))
    }

    /// Full leaderboard for detail view
    var fullLeaderboard: [GolferLine] {
        leaderboard
    }

    /// Tour display name
    var tourDisplayName: String {
        switch tour.lowercased() {
        case "pga": return "PGA Tour"
        case "lpga": return "LPGA Tour"
        default: return tour.uppercased()
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, tour, venue, location, startDate, endDate
        case currentRound, roundStatus, purse, winner, leaderboard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tour = try container.decode(String.self, forKey: .tour)
        venue = try container.decode(String.self, forKey: .venue)
        location = try container.decode(String.self, forKey: .location)
        currentRound = try container.decode(Int.self, forKey: .currentRound)
        roundStatus = try container.decode(String.self, forKey: .roundStatus)
        purse = try container.decodeIfPresent(String.self, forKey: .purse)
        winner = try container.decodeIfPresent(GolfWinner.self, forKey: .winner)
        leaderboard = try container.decode([GolferLine].self, forKey: .leaderboard)

        // Handle date decoding - can be string or Date
        if let startStr = try? container.decode(String.self, forKey: .startDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            startDate = formatter.date(from: startStr) ?? Date()
        } else {
            startDate = try container.decode(Date.self, forKey: .startDate)
        }

        if let endStr = try? container.decode(String.self, forKey: .endDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            endDate = formatter.date(from: endStr) ?? Date()
        } else {
            endDate = try container.decode(Date.self, forKey: .endDate)
        }
    }

    init(
        id: String,
        name: String,
        tour: String,
        venue: String,
        location: String,
        startDate: Date,
        endDate: Date,
        currentRound: Int,
        roundStatus: String,
        purse: String? = nil,
        winner: GolfWinner? = nil,
        leaderboard: [GolferLine] = []
    ) {
        self.id = id
        self.name = name
        self.tour = tour
        self.venue = venue
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.currentRound = currentRound
        self.roundStatus = roundStatus
        self.purse = purse
        self.winner = winner
        self.leaderboard = leaderboard
    }
}

// MARK: - Golf Scoreboard Response

struct GolfScoreboardResponse: Codable, Sendable {
    let league: String
    let weekStart: String
    let weekEnd: String
    let tournaments: [GolfTournament]
    let lastUpdated: String

    /// Parsed week start date
    var weekStartDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekStart) ?? Date()
    }

    /// Parsed week end date
    var weekEndDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekEnd) ?? Date()
    }

    /// Week display string (e.g., "Week of Jan 12-18")
    var weekDisplay: String {
        let startDate = weekStartDate
        let endDate = weekEndDate

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: startDate)
        formatter.dateFormat = "d"
        let endStr = formatter.string(from: endDate)

        return "Week of \(startStr)-\(endStr)"
    }
}
