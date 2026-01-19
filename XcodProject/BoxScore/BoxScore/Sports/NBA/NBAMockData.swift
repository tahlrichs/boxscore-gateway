//
//  NBAMockData.swift
//  BoxScore
//
//  Mock NBA game data for development
//

import Foundation

enum NBAMockData {
    
    // MARK: - Teams
    
    static let lakers = TeamInfo(
        id: "lal",
        abbreviation: "LAL",
        name: "Lakers",
        city: "Los Angeles",
        primaryColor: "#552583"
    )
    
    static let celtics = TeamInfo(
        id: "bos",
        abbreviation: "BOS",
        name: "Celtics",
        city: "Boston",
        primaryColor: "#007A33"
    )
    
    static let warriors = TeamInfo(
        id: "gsw",
        abbreviation: "GSW",
        name: "Warriors",
        city: "Golden State",
        primaryColor: "#1D428A"
    )
    
    static let nuggets = TeamInfo(
        id: "den",
        abbreviation: "DEN",
        name: "Nuggets",
        city: "Denver",
        primaryColor: "#0E2240"
    )
    
    static let heat = TeamInfo(
        id: "mia",
        abbreviation: "MIA",
        name: "Heat",
        city: "Miami",
        primaryColor: "#98002E"
    )
    
    static let knicks = TeamInfo(
        id: "nyk",
        abbreviation: "NYK",
        name: "Knicks",
        city: "New York",
        primaryColor: "#006BB6"
    )
    
    // MARK: - Game 1: Lakers vs Celtics (Final)
    
    static let lakersBoxScore = NBATeamBoxScore(
        teamId: "lal",
        teamName: "Lakers",
        starters: [
            NBAPlayerLine(
                id: "lal_1",
                name: "LeBron James",
                jersey: "23",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 38, points: 32, fgMade: 12, fgAttempted: 22,
                    threeMade: 3, threeAttempted: 8, ftMade: 5, ftAttempted: 6,
                    offRebounds: 1, defRebounds: 7, assists: 9, steals: 2,
                    blocks: 1, turnovers: 4, fouls: 2, plusMinus: 12
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "lal_2",
                name: "Anthony Davis",
                jersey: "3",
                position: "PF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 36, points: 28, fgMade: 11, fgAttempted: 18,
                    threeMade: 1, threeAttempted: 3, ftMade: 5, ftAttempted: 8,
                    offRebounds: 4, defRebounds: 10, assists: 3, steals: 1,
                    blocks: 3, turnovers: 2, fouls: 3, plusMinus: 8
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "lal_3",
                name: "Austin Reaves",
                jersey: "15",
                position: "SG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 34, points: 18, fgMade: 7, fgAttempted: 14,
                    threeMade: 3, threeAttempted: 7, ftMade: 1, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 4, assists: 5, steals: 1,
                    blocks: 0, turnovers: 2, fouls: 2, plusMinus: 6
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "lal_4",
                name: "D'Angelo Russell",
                jersey: "1",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 30, points: 14, fgMade: 5, fgAttempted: 12,
                    threeMade: 2, threeAttempted: 6, ftMade: 2, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 2, assists: 7, steals: 0,
                    blocks: 0, turnovers: 3, fouls: 1, plusMinus: 4
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "lal_5",
                name: "Rui Hachimura",
                jersey: "28",
                position: "PF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 28, points: 12, fgMade: 5, fgAttempted: 9,
                    threeMade: 1, threeAttempted: 3, ftMade: 1, ftAttempted: 2,
                    offRebounds: 1, defRebounds: 3, assists: 1, steals: 0,
                    blocks: 1, turnovers: 1, fouls: 4, plusMinus: 2
                ),
                dnpReason: nil
            ),
        ],
        bench: [
            NBAPlayerLine(
                id: "lal_6",
                name: "Taurean Prince",
                jersey: "12",
                position: "SF",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 22, points: 8, fgMade: 3, fgAttempted: 7,
                    threeMade: 2, threeAttempted: 5, ftMade: 0, ftAttempted: 0,
                    offRebounds: 0, defRebounds: 3, assists: 2, steals: 1,
                    blocks: 0, turnovers: 1, fouls: 2, plusMinus: -2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "lal_7",
                name: "Gabe Vincent",
                jersey: "7",
                position: "PG",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 18, points: 6, fgMade: 2, fgAttempted: 6,
                    threeMade: 1, threeAttempted: 4, ftMade: 1, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 1, assists: 3, steals: 0,
                    blocks: 0, turnovers: 0, fouls: 1, plusMinus: -4
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "lal_8",
                name: "Christian Wood",
                jersey: "35",
                position: "C",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 14, points: 4, fgMade: 2, fgAttempted: 5,
                    threeMade: 0, threeAttempted: 2, ftMade: 0, ftAttempted: 0,
                    offRebounds: 2, defRebounds: 4, assists: 0, steals: 0,
                    blocks: 1, turnovers: 1, fouls: 3, plusMinus: -6
                ),
                dnpReason: nil
            ),
        ],
        dnp: [
            NBAPlayerLine(
                id: "lal_9",
                name: "Jarred Vanderbilt",
                jersey: "2",
                position: "PF",
                isStarter: false,
                hasEnteredGame: false,
                stats: nil,
                dnpReason: "Injury - Foot"
            ),
            NBAPlayerLine(
                id: "lal_10",
                name: "Maxwell Lewis",
                jersey: "21",
                position: "SF",
                isStarter: false,
                hasEnteredGame: false,
                stats: nil,
                dnpReason: "Coach's Decision"
            ),
        ],
        teamTotals: NBATeamTotals(
            minutes: 240, points: 122, fgMade: 47, fgAttempted: 93, fgPercentage: 50.5,
            threeMade: 13, threeAttempted: 38, threePercentage: 34.2,
            ftMade: 15, ftAttempted: 22, ftPercentage: 68.2,
            offRebounds: 8, defRebounds: 34, totalRebounds: 42,
            assists: 30, steals: 5, blocks: 6, turnovers: 14, fouls: 18
        )
    )
    
    static let celticsBoxScore = NBATeamBoxScore(
        teamId: "bos",
        teamName: "Celtics",
        starters: [
            NBAPlayerLine(
                id: "bos_1",
                name: "Jayson Tatum",
                jersey: "0",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 40, points: 35, fgMade: 13, fgAttempted: 25,
                    threeMade: 4, threeAttempted: 10, ftMade: 5, ftAttempted: 6,
                    offRebounds: 0, defRebounds: 9, assists: 6, steals: 1,
                    blocks: 0, turnovers: 3, fouls: 2, plusMinus: -8
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "bos_2",
                name: "Jaylen Brown",
                jersey: "7",
                position: "SG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 38, points: 28, fgMade: 11, fgAttempted: 21,
                    threeMade: 3, threeAttempted: 8, ftMade: 3, ftAttempted: 4,
                    offRebounds: 1, defRebounds: 5, assists: 4, steals: 2,
                    blocks: 1, turnovers: 2, fouls: 3, plusMinus: -6
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "bos_3",
                name: "Derrick White",
                jersey: "9",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 35, points: 16, fgMade: 6, fgAttempted: 13,
                    threeMade: 2, threeAttempted: 6, ftMade: 2, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 3, assists: 5, steals: 1,
                    blocks: 2, turnovers: 1, fouls: 2, plusMinus: -4
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "bos_4",
                name: "Jrue Holiday",
                jersey: "4",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 34, points: 14, fgMade: 5, fgAttempted: 11,
                    threeMade: 2, threeAttempted: 5, ftMade: 2, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 4, assists: 8, steals: 2,
                    blocks: 0, turnovers: 2, fouls: 2, plusMinus: -10
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "bos_5",
                name: "Kristaps Porzingis",
                jersey: "8",
                position: "C",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 30, points: 18, fgMade: 7, fgAttempted: 14,
                    threeMade: 2, threeAttempted: 5, ftMade: 2, ftAttempted: 3,
                    offRebounds: 2, defRebounds: 6, assists: 1, steals: 0,
                    blocks: 3, turnovers: 1, fouls: 4, plusMinus: -2
                ),
                dnpReason: nil
            ),
        ],
        bench: [
            NBAPlayerLine(
                id: "bos_6",
                name: "Al Horford",
                jersey: "42",
                position: "C",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 20, points: 6, fgMade: 2, fgAttempted: 5,
                    threeMade: 1, threeAttempted: 3, ftMade: 1, ftAttempted: 2,
                    offRebounds: 1, defRebounds: 4, assists: 2, steals: 0,
                    blocks: 1, turnovers: 0, fouls: 2, plusMinus: 2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "bos_7",
                name: "Payton Pritchard",
                jersey: "11",
                position: "PG",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 16, points: 8, fgMade: 3, fgAttempted: 7,
                    threeMade: 2, threeAttempted: 5, ftMade: 0, ftAttempted: 0,
                    offRebounds: 0, defRebounds: 1, assists: 2, steals: 0,
                    blocks: 0, turnovers: 1, fouls: 1, plusMinus: 4
                ),
                dnpReason: nil
            ),
        ],
        dnp: [
            NBAPlayerLine(
                id: "bos_8",
                name: "Sam Hauser",
                jersey: "30",
                position: "SF",
                isStarter: false,
                hasEnteredGame: false,
                stats: nil,
                dnpReason: "Coach's Decision"
            ),
        ],
        teamTotals: NBATeamTotals(
            minutes: 240, points: 117, fgMade: 44, fgAttempted: 96, fgPercentage: 45.8,
            threeMade: 14, threeAttempted: 42, threePercentage: 33.3,
            ftMade: 15, ftAttempted: 19, ftPercentage: 78.9,
            offRebounds: 4, defRebounds: 32, totalRebounds: 36,
            assists: 28, steals: 6, blocks: 7, turnovers: 10, fouls: 16
        )
    )
    
    // Helper to create dates relative to today
    private static func dateOffset(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: Date()))!
    }
    
    static let game1 = Game(
        id: "nba_1",
        sport: .nba,
        gameDate: dateOffset(0), // Today
        status: .final,
        awayTeam: lakers,
        homeTeam: celtics,
        awayScore: 122,
        homeScore: 117,
        awayBoxScore: .nba(lakersBoxScore),
        homeBoxScore: .nba(celticsBoxScore)
    )
    
    // MARK: - Game 2: Warriors vs Nuggets (Live)
    
    static let warriorsBoxScore = NBATeamBoxScore(
        teamId: "gsw",
        teamName: "Warriors",
        starters: [
            NBAPlayerLine(
                id: "gsw_1",
                name: "Stephen Curry",
                jersey: "30",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 28, points: 24, fgMade: 8, fgAttempted: 16,
                    threeMade: 5, threeAttempted: 11, ftMade: 3, ftAttempted: 3,
                    offRebounds: 0, defRebounds: 4, assists: 6, steals: 1,
                    blocks: 0, turnovers: 2, fouls: 1, plusMinus: 5
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "gsw_2",
                name: "Klay Thompson",
                jersey: "11",
                position: "SG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 26, points: 16, fgMade: 6, fgAttempted: 14,
                    threeMade: 3, threeAttempted: 9, ftMade: 1, ftAttempted: 1,
                    offRebounds: 0, defRebounds: 2, assists: 2, steals: 0,
                    blocks: 0, turnovers: 1, fouls: 2, plusMinus: 3
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "gsw_3",
                name: "Andrew Wiggins",
                jersey: "22",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 27, points: 12, fgMade: 5, fgAttempted: 10,
                    threeMade: 1, threeAttempted: 4, ftMade: 1, ftAttempted: 2,
                    offRebounds: 1, defRebounds: 4, assists: 2, steals: 1,
                    blocks: 1, turnovers: 0, fouls: 2, plusMinus: 2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "gsw_4",
                name: "Draymond Green",
                jersey: "23",
                position: "PF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 25, points: 6, fgMade: 3, fgAttempted: 6,
                    threeMade: 0, threeAttempted: 2, ftMade: 0, ftAttempted: 0,
                    offRebounds: 1, defRebounds: 5, assists: 7, steals: 2,
                    blocks: 1, turnovers: 3, fouls: 3, plusMinus: 4
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "gsw_5",
                name: "Kevon Looney",
                jersey: "5",
                position: "C",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 20, points: 4, fgMade: 2, fgAttempted: 4,
                    threeMade: 0, threeAttempted: 0, ftMade: 0, ftAttempted: 0,
                    offRebounds: 3, defRebounds: 5, assists: 2, steals: 0,
                    blocks: 0, turnovers: 0, fouls: 2, plusMinus: 1
                ),
                dnpReason: nil
            ),
        ],
        bench: [
            NBAPlayerLine(
                id: "gsw_6",
                name: "Jonathan Kuminga",
                jersey: "00",
                position: "PF",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 14, points: 8, fgMade: 3, fgAttempted: 6,
                    threeMade: 1, threeAttempted: 2, ftMade: 1, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 2, assists: 1, steals: 0,
                    blocks: 0, turnovers: 1, fouls: 1, plusMinus: -2
                ),
                dnpReason: nil
            ),
        ],
        dnp: [],
        teamTotals: NBATeamTotals(
            minutes: 140, points: 70, fgMade: 27, fgAttempted: 56, fgPercentage: 48.2,
            threeMade: 10, threeAttempted: 28, threePercentage: 35.7,
            ftMade: 6, ftAttempted: 8, ftPercentage: 75.0,
            offRebounds: 5, defRebounds: 22, totalRebounds: 27,
            assists: 20, steals: 4, blocks: 2, turnovers: 7, fouls: 11
        )
    )
    
    static let nuggetsBoxScore = NBATeamBoxScore(
        teamId: "den",
        teamName: "Nuggets",
        starters: [
            NBAPlayerLine(
                id: "den_1",
                name: "Nikola Jokic",
                jersey: "15",
                position: "C",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 28, points: 22, fgMade: 9, fgAttempted: 14,
                    threeMade: 1, threeAttempted: 3, ftMade: 3, ftAttempted: 4,
                    offRebounds: 2, defRebounds: 8, assists: 8, steals: 1,
                    blocks: 0, turnovers: 2, fouls: 2, plusMinus: -3
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "den_2",
                name: "Jamal Murray",
                jersey: "27",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 26, points: 18, fgMade: 7, fgAttempted: 15,
                    threeMade: 2, threeAttempted: 6, ftMade: 2, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 2, assists: 4, steals: 0,
                    blocks: 0, turnovers: 1, fouls: 1, plusMinus: -5
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "den_3",
                name: "Michael Porter Jr.",
                jersey: "1",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 25, points: 14, fgMade: 5, fgAttempted: 11,
                    threeMade: 2, threeAttempted: 6, ftMade: 2, ftAttempted: 2,
                    offRebounds: 1, defRebounds: 4, assists: 1, steals: 0,
                    blocks: 0, turnovers: 0, fouls: 2, plusMinus: -4
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "den_4",
                name: "Aaron Gordon",
                jersey: "50",
                position: "PF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 24, points: 8, fgMade: 4, fgAttempted: 8,
                    threeMade: 0, threeAttempted: 2, ftMade: 0, ftAttempted: 0,
                    offRebounds: 2, defRebounds: 3, assists: 2, steals: 1,
                    blocks: 1, turnovers: 1, fouls: 3, plusMinus: -2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "den_5",
                name: "Kentavious Caldwell-Pope",
                jersey: "5",
                position: "SG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 22, points: 6, fgMade: 2, fgAttempted: 6,
                    threeMade: 1, threeAttempted: 4, ftMade: 1, ftAttempted: 1,
                    offRebounds: 0, defRebounds: 2, assists: 1, steals: 1,
                    blocks: 0, turnovers: 0, fouls: 1, plusMinus: -1
                ),
                dnpReason: nil
            ),
        ],
        bench: [],
        dnp: [],
        teamTotals: NBATeamTotals(
            minutes: 125, points: 68, fgMade: 27, fgAttempted: 54, fgPercentage: 50.0,
            threeMade: 6, threeAttempted: 21, threePercentage: 28.6,
            ftMade: 8, ftAttempted: 9, ftPercentage: 88.9,
            offRebounds: 5, defRebounds: 19, totalRebounds: 24,
            assists: 16, steals: 3, blocks: 1, turnovers: 4, fouls: 9
        )
    )
    
    static let game2 = Game(
        id: "nba_2",
        sport: .nba,
        gameDate: dateOffset(0), // Today
        status: .live(period: "Q3", clock: "4:22"),
        awayTeam: warriors,
        homeTeam: nuggets,
        awayScore: 70,
        homeScore: 68,
        awayBoxScore: .nba(warriorsBoxScore),
        homeBoxScore: .nba(nuggetsBoxScore)
    )
    
    // MARK: - Game 3: Heat vs Knicks (Final OT)
    
    static let heatBoxScore = NBATeamBoxScore(
        teamId: "mia",
        teamName: "Heat",
        starters: [
            NBAPlayerLine(
                id: "mia_1",
                name: "Jimmy Butler",
                jersey: "22",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 42, points: 30, fgMade: 10, fgAttempted: 20,
                    threeMade: 2, threeAttempted: 5, ftMade: 8, ftAttempted: 10,
                    offRebounds: 1, defRebounds: 6, assists: 8, steals: 3,
                    blocks: 0, turnovers: 4, fouls: 3, plusMinus: 2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "mia_2",
                name: "Bam Adebayo",
                jersey: "13",
                position: "C",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 40, points: 22, fgMade: 9, fgAttempted: 16,
                    threeMade: 0, threeAttempted: 1, ftMade: 4, ftAttempted: 6,
                    offRebounds: 3, defRebounds: 9, assists: 5, steals: 1,
                    blocks: 2, turnovers: 2, fouls: 4, plusMinus: 0
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "mia_3",
                name: "Tyler Herro",
                jersey: "14",
                position: "SG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 38, points: 24, fgMade: 8, fgAttempted: 18,
                    threeMade: 4, threeAttempted: 10, ftMade: 4, ftAttempted: 4,
                    offRebounds: 0, defRebounds: 4, assists: 4, steals: 0,
                    blocks: 0, turnovers: 2, fouls: 2, plusMinus: 4
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "mia_4",
                name: "Kyle Lowry",
                jersey: "7",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 34, points: 10, fgMade: 4, fgAttempted: 10,
                    threeMade: 2, threeAttempted: 6, ftMade: 0, ftAttempted: 0,
                    offRebounds: 0, defRebounds: 3, assists: 7, steals: 1,
                    blocks: 0, turnovers: 3, fouls: 3, plusMinus: -2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "mia_5",
                name: "Caleb Martin",
                jersey: "16",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 32, points: 12, fgMade: 4, fgAttempted: 9,
                    threeMade: 2, threeAttempted: 5, ftMade: 2, ftAttempted: 2,
                    offRebounds: 1, defRebounds: 3, assists: 2, steals: 1,
                    blocks: 1, turnovers: 1, fouls: 2, plusMinus: 1
                ),
                dnpReason: nil
            ),
        ],
        bench: [
            NBAPlayerLine(
                id: "mia_6",
                name: "Kevin Love",
                jersey: "42",
                position: "PF",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 18, points: 8, fgMade: 3, fgAttempted: 6,
                    threeMade: 2, threeAttempted: 4, ftMade: 0, ftAttempted: 0,
                    offRebounds: 1, defRebounds: 5, assists: 1, steals: 0,
                    blocks: 0, turnovers: 0, fouls: 2, plusMinus: 3
                ),
                dnpReason: nil
            ),
        ],
        dnp: [],
        teamTotals: NBATeamTotals(
            minutes: 265, points: 106, fgMade: 38, fgAttempted: 79, fgPercentage: 48.1,
            threeMade: 12, threeAttempted: 31, threePercentage: 38.7,
            ftMade: 18, ftAttempted: 22, ftPercentage: 81.8,
            offRebounds: 6, defRebounds: 30, totalRebounds: 36,
            assists: 27, steals: 6, blocks: 3, turnovers: 12, fouls: 16
        )
    )
    
    static let knicksBoxScore = NBATeamBoxScore(
        teamId: "nyk",
        teamName: "Knicks",
        starters: [
            NBAPlayerLine(
                id: "nyk_1",
                name: "Jalen Brunson",
                jersey: "11",
                position: "PG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 44, points: 34, fgMade: 12, fgAttempted: 24,
                    threeMade: 3, threeAttempted: 8, ftMade: 7, ftAttempted: 8,
                    offRebounds: 0, defRebounds: 3, assists: 7, steals: 1,
                    blocks: 0, turnovers: 2, fouls: 2, plusMinus: -1
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "nyk_2",
                name: "Julius Randle",
                jersey: "30",
                position: "PF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 42, points: 26, fgMade: 9, fgAttempted: 21,
                    threeMade: 2, threeAttempted: 7, ftMade: 6, ftAttempted: 8,
                    offRebounds: 2, defRebounds: 10, assists: 5, steals: 0,
                    blocks: 0, turnovers: 4, fouls: 4, plusMinus: -3
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "nyk_3",
                name: "RJ Barrett",
                jersey: "9",
                position: "SG",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 38, points: 18, fgMade: 7, fgAttempted: 16,
                    threeMade: 1, threeAttempted: 5, ftMade: 3, ftAttempted: 4,
                    offRebounds: 1, defRebounds: 4, assists: 3, steals: 1,
                    blocks: 0, turnovers: 2, fouls: 3, plusMinus: 0
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "nyk_4",
                name: "Mitchell Robinson",
                jersey: "23",
                position: "C",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 30, points: 10, fgMade: 5, fgAttempted: 7,
                    threeMade: 0, threeAttempted: 0, ftMade: 0, ftAttempted: 2,
                    offRebounds: 5, defRebounds: 7, assists: 1, steals: 0,
                    blocks: 3, turnovers: 1, fouls: 5, plusMinus: 2
                ),
                dnpReason: nil
            ),
            NBAPlayerLine(
                id: "nyk_5",
                name: "Josh Hart",
                jersey: "3",
                position: "SF",
                isStarter: true,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 40, points: 14, fgMade: 5, fgAttempted: 11,
                    threeMade: 2, threeAttempted: 5, ftMade: 2, ftAttempted: 2,
                    offRebounds: 2, defRebounds: 8, assists: 4, steals: 2,
                    blocks: 0, turnovers: 1, fouls: 2, plusMinus: 1
                ),
                dnpReason: nil
            ),
        ],
        bench: [
            NBAPlayerLine(
                id: "nyk_6",
                name: "Immanuel Quickley",
                jersey: "5",
                position: "PG",
                isStarter: false,
                hasEnteredGame: true,
                stats: NBAStatLine(
                    minutes: 22, points: 12, fgMade: 4, fgAttempted: 10,
                    threeMade: 2, threeAttempted: 6, ftMade: 2, ftAttempted: 2,
                    offRebounds: 0, defRebounds: 2, assists: 3, steals: 0,
                    blocks: 0, turnovers: 1, fouls: 1, plusMinus: -4
                ),
                dnpReason: nil
            ),
        ],
        dnp: [
            NBAPlayerLine(
                id: "nyk_7",
                name: "Evan Fournier",
                jersey: "13",
                position: "SG",
                isStarter: false,
                hasEnteredGame: false,
                stats: nil,
                dnpReason: "Coach's Decision"
            ),
        ],
        teamTotals: NBATeamTotals(
            minutes: 265, points: 104, fgMade: 37, fgAttempted: 89, fgPercentage: 41.6,
            threeMade: 10, threeAttempted: 31, threePercentage: 32.3,
            ftMade: 20, ftAttempted: 26, ftPercentage: 76.9,
            offRebounds: 10, defRebounds: 34, totalRebounds: 44,
            assists: 23, steals: 4, blocks: 3, turnovers: 11, fouls: 19
        )
    )
    
    static let game3 = Game(
        id: "nba_3",
        sport: .nba,
        gameDate: dateOffset(-1), // Yesterday
        status: .finalOvertime(periods: 1),
        awayTeam: heat,
        homeTeam: knicks,
        awayScore: 106,
        homeScore: 104,
        awayBoxScore: .nba(heatBoxScore),
        homeBoxScore: .nba(knicksBoxScore)
    )
    
    // MARK: - All Games
    
    static let allGames: [Game] = [game1, game2, game3]
}

