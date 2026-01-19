//
//  NHLMockData.swift
//  BoxScore
//
//  Mock NHL game data for development
//

import Foundation

enum NHLMockData {
    
    // MARK: - Teams
    
    static let bruins = TeamInfo(
        id: "bos_nhl",
        abbreviation: "BOS",
        name: "Bruins",
        city: "Boston",
        primaryColor: "#FFB81C",
        conference: "Eastern",
        division: "Atlantic"
    )
    
    static let rangers = TeamInfo(
        id: "nyr",
        abbreviation: "NYR",
        name: "Rangers",
        city: "New York",
        primaryColor: "#0038A8",
        conference: "Eastern",
        division: "Metropolitan"
    )
    
    static let avalanche = TeamInfo(
        id: "col",
        abbreviation: "COL",
        name: "Avalanche",
        city: "Colorado",
        primaryColor: "#6F263D",
        conference: "Western",
        division: "Central"
    )
    
    static let oilers = TeamInfo(
        id: "edm",
        abbreviation: "EDM",
        name: "Oilers",
        city: "Edmonton",
        primaryColor: "#FF4C00",
        conference: "Western",
        division: "Pacific"
    )
    
    static let maple_leafs = TeamInfo(
        id: "tor",
        abbreviation: "TOR",
        name: "Maple Leafs",
        city: "Toronto",
        primaryColor: "#00205B",
        conference: "Eastern",
        division: "Atlantic"
    )
    
    static let panthers = TeamInfo(
        id: "fla",
        abbreviation: "FLA",
        name: "Panthers",
        city: "Florida",
        primaryColor: "#041E42",
        conference: "Eastern",
        division: "Atlantic"
    )
    
    // MARK: - Game 1: Bruins vs Rangers (Final)
    
    static let bruinsBoxScore = NHLTeamBoxScore(
        teamId: "bos_nhl",
        teamName: "Bruins",
        skaters: [
            NHLSkaterLine(
                id: "bos_1",
                name: "David Pastrnak",
                jersey: "88",
                position: "RW",
                stats: NHLSkaterStats(
                    goals: 2, assists: 1, plusMinus: 2, penaltyMinutes: 0,
                    shots: 6, hits: 1, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1245, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 26
                )
            ),
            NHLSkaterLine(
                id: "bos_2",
                name: "Brad Marchand",
                jersey: "63",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 0, assists: 2, plusMinus: 1, penaltyMinutes: 2,
                    shots: 4, hits: 3, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1198, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 25
                )
            ),
            NHLSkaterLine(
                id: "bos_3",
                name: "Patrice Bergeron",
                jersey: "37",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: 1, penaltyMinutes: 0,
                    shots: 3, hits: 2, blockedShots: 1, faceoffWins: 14, faceoffLosses: 8,
                    timeOnIceSeconds: 1312, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 28
                )
            ),
            NHLSkaterLine(
                id: "bos_4",
                name: "Charlie McAvoy",
                jersey: "73",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: 2, penaltyMinutes: 0,
                    shots: 2, hits: 4, blockedShots: 3, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1456, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 30
                )
            ),
            NHLSkaterLine(
                id: "bos_5",
                name: "Hampus Lindholm",
                jersey: "27",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: 1, penaltyMinutes: 2,
                    shots: 1, hits: 5, blockedShots: 4, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1389, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 29
                )
            ),
            NHLSkaterLine(
                id: "bos_6",
                name: "Pavel Zacha",
                jersey: "18",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: 0, penaltyMinutes: 0,
                    shots: 2, hits: 1, blockedShots: 0, faceoffWins: 8, faceoffLosses: 6,
                    timeOnIceSeconds: 987, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 22
                )
            ),
            NHLSkaterLine(
                id: "bos_7",
                name: "Jake DeBrusk",
                jersey: "74",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: 0, penaltyMinutes: 0,
                    shots: 3, hits: 2, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 892, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 20
                )
            ),
            NHLSkaterLine(
                id: "bos_8",
                name: "Trent Frederic",
                jersey: "11",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -1, penaltyMinutes: 5,
                    shots: 1, hits: 6, blockedShots: 1, faceoffWins: 4, faceoffLosses: 5,
                    timeOnIceSeconds: 756, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 18
                )
            ),
            NHLSkaterLine(
                id: "bos_9",
                name: "Brandon Carlo",
                jersey: "25",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: 0, penaltyMinutes: 0,
                    shots: 0, hits: 3, blockedShots: 2, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1123, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 24
                )
            ),
            NHLSkaterLine(
                id: "bos_10",
                name: "Matt Grzelcyk",
                jersey: "48",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -1, penaltyMinutes: 0,
                    shots: 1, hits: 1, blockedShots: 1, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 876, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 19
                )
            ),
        ],
        goalies: [
            NHLGoalieLine(
                id: "bos_g1",
                name: "Jeremy Swayman",
                jersey: "1",
                stats: NHLGoalieStats(
                    saves: 28, shotsAgainst: 31, goalsAgainst: 3,
                    timeOnIceSeconds: 3600, evenStrengthSaves: 22,
                    powerPlaySaves: 4, shortHandedSaves: 2,
                    evenStrengthShotsAgainst: 24, powerPlayShotsAgainst: 5,
                    shortHandedShotsAgainst: 2
                ),
                decision: "W"
            ),
        ],
        teamTotals: NHLTeamTotals(
            goals: 4, assists: 5, shots: 32, hits: 28, blockedShots: 12,
            penaltyMinutes: 9, faceoffWins: 26, faceoffLosses: 32,
            powerPlayGoals: 1, powerPlayOpportunities: 4, shortHandedGoals: 0,
            takeaways: 6, giveaways: 8
        ),
        scratches: []
    )
    
    static let rangersBoxScore = NHLTeamBoxScore(
        teamId: "nyr",
        teamName: "Rangers",
        skaters: [
            NHLSkaterLine(
                id: "nyr_1",
                name: "Artemi Panarin",
                jersey: "10",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 1, assists: 1, plusMinus: 0, penaltyMinutes: 0,
                    shots: 5, hits: 0, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1278, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 27
                )
            ),
            NHLSkaterLine(
                id: "nyr_2",
                name: "Adam Fox",
                jersey: "23",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 2, plusMinus: -1, penaltyMinutes: 0,
                    shots: 3, hits: 2, blockedShots: 2, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1534, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 31
                )
            ),
            NHLSkaterLine(
                id: "nyr_3",
                name: "Mika Zibanejad",
                jersey: "93",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: -1, penaltyMinutes: 0,
                    shots: 4, hits: 1, blockedShots: 0, faceoffWins: 12, faceoffLosses: 10,
                    timeOnIceSeconds: 1289, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 27
                )
            ),
            NHLSkaterLine(
                id: "nyr_4",
                name: "Chris Kreider",
                jersey: "20",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: 0, penaltyMinutes: 2,
                    shots: 4, hits: 3, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1145, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 24
                )
            ),
            NHLSkaterLine(
                id: "nyr_5",
                name: "K'Andre Miller",
                jersey: "79",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -2, penaltyMinutes: 2,
                    shots: 1, hits: 4, blockedShots: 3, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1367, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 28
                )
            ),
            NHLSkaterLine(
                id: "nyr_6",
                name: "Vincent Trocheck",
                jersey: "16",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: 0, penaltyMinutes: 0,
                    shots: 2, hits: 2, blockedShots: 1, faceoffWins: 10, faceoffLosses: 7,
                    timeOnIceSeconds: 1056, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 23
                )
            ),
            NHLSkaterLine(
                id: "nyr_7",
                name: "Alexis Lafrenière",
                jersey: "13",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -1, penaltyMinutes: 0,
                    shots: 2, hits: 1, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 923, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 21
                )
            ),
            NHLSkaterLine(
                id: "nyr_8",
                name: "Jacob Trouba",
                jersey: "8",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: 0, penaltyMinutes: 2,
                    shots: 2, hits: 5, blockedShots: 2, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1234, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 26
                )
            ),
        ],
        goalies: [
            NHLGoalieLine(
                id: "nyr_g1",
                name: "Igor Shesterkin",
                jersey: "31",
                stats: NHLGoalieStats(
                    saves: 28, shotsAgainst: 32, goalsAgainst: 4,
                    timeOnIceSeconds: 3600, evenStrengthSaves: 23,
                    powerPlaySaves: 3, shortHandedSaves: 2,
                    evenStrengthShotsAgainst: 26, powerPlayShotsAgainst: 4,
                    shortHandedShotsAgainst: 2
                ),
                decision: "L"
            ),
        ],
        teamTotals: NHLTeamTotals(
            goals: 3, assists: 3, shots: 31, hits: 22, blockedShots: 10,
            penaltyMinutes: 6, faceoffWins: 32, faceoffLosses: 26,
            powerPlayGoals: 1, powerPlayOpportunities: 3, shortHandedGoals: 0,
            takeaways: 5, giveaways: 7
        ),
        scratches: [
            NHLScratchPlayer(id: "nyr_s1", name: "Barclay Goodrow", jersey: "21", position: "C", reason: "Injury - Lower Body")
        ]
    )
    
    // Helper to create dates relative to today
    private static func dateOffset(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: Date()))!
    }
    
    static let game1 = Game(
        id: "nhl_1",
        sport: .nhl,
        gameDate: dateOffset(0), // Today
        status: .final,
        awayTeam: bruins,
        homeTeam: rangers,
        awayScore: 4,
        homeScore: 3,
        awayBoxScore: .nhl(bruinsBoxScore),
        homeBoxScore: .nhl(rangersBoxScore),
        venue: Venue(id: "msg", name: "Madison Square Garden", city: "New York", state: "NY")
    )
    
    // MARK: - Game 2: Avalanche vs Oilers (Live)
    
    static let avalancheBoxScore = NHLTeamBoxScore(
        teamId: "col",
        teamName: "Avalanche",
        skaters: [
            NHLSkaterLine(
                id: "col_1",
                name: "Nathan MacKinnon",
                jersey: "29",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 2, plusMinus: 1, penaltyMinutes: 0,
                    shots: 5, hits: 1, blockedShots: 0, faceoffWins: 8, faceoffLosses: 5,
                    timeOnIceSeconds: 856, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 18
                )
            ),
            NHLSkaterLine(
                id: "col_2",
                name: "Cale Makar",
                jersey: "8",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 1, assists: 1, plusMinus: 2, penaltyMinutes: 0,
                    shots: 4, hits: 2, blockedShots: 1, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 978, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 20
                )
            ),
            NHLSkaterLine(
                id: "col_3",
                name: "Mikko Rantanen",
                jersey: "96",
                position: "RW",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: 1, penaltyMinutes: 0,
                    shots: 3, hits: 1, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 812, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 17
                )
            ),
            NHLSkaterLine(
                id: "col_4",
                name: "Devon Toews",
                jersey: "7",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: 1, penaltyMinutes: 0,
                    shots: 1, hits: 2, blockedShots: 2, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 934, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 19
                )
            ),
            NHLSkaterLine(
                id: "col_5",
                name: "Valeri Nichushkin",
                jersey: "13",
                position: "RW",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: 0, penaltyMinutes: 2,
                    shots: 2, hits: 3, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 723, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 15
                )
            ),
        ],
        goalies: [
            NHLGoalieLine(
                id: "col_g1",
                name: "Alexandar Georgiev",
                jersey: "40",
                stats: NHLGoalieStats(
                    saves: 18, shotsAgainst: 21, goalsAgainst: 3,
                    timeOnIceSeconds: 2400, evenStrengthSaves: 14,
                    powerPlaySaves: 3, shortHandedSaves: 1,
                    evenStrengthShotsAgainst: 16, powerPlayShotsAgainst: 4,
                    shortHandedShotsAgainst: 1
                ),
                decision: nil
            ),
        ],
        teamTotals: NHLTeamTotals(
            goals: 3, assists: 5, shots: 22, hits: 14, blockedShots: 8,
            penaltyMinutes: 4, faceoffWins: 15, faceoffLosses: 18,
            powerPlayGoals: 1, powerPlayOpportunities: 3, shortHandedGoals: 0,
            takeaways: 4, giveaways: 5
        ),
        scratches: []
    )
    
    static let oilersBoxScore = NHLTeamBoxScore(
        teamId: "edm",
        teamName: "Oilers",
        skaters: [
            NHLSkaterLine(
                id: "edm_1",
                name: "Connor McDavid",
                jersey: "97",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 1, plusMinus: -1, penaltyMinutes: 0,
                    shots: 6, hits: 0, blockedShots: 0, faceoffWins: 10, faceoffLosses: 8,
                    timeOnIceSeconds: 923, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 19
                )
            ),
            NHLSkaterLine(
                id: "edm_2",
                name: "Leon Draisaitl",
                jersey: "29",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 1, plusMinus: 0, penaltyMinutes: 0,
                    shots: 4, hits: 1, blockedShots: 0, faceoffWins: 6, faceoffLosses: 4,
                    timeOnIceSeconds: 878, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 18
                )
            ),
            NHLSkaterLine(
                id: "edm_3",
                name: "Zach Hyman",
                jersey: "18",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: 0, penaltyMinutes: 0,
                    shots: 3, hits: 2, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 756, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 16
                )
            ),
            NHLSkaterLine(
                id: "edm_4",
                name: "Darnell Nurse",
                jersey: "25",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: -1, penaltyMinutes: 2,
                    shots: 2, hits: 3, blockedShots: 2, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 912, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 19
                )
            ),
            NHLSkaterLine(
                id: "edm_5",
                name: "Evan Bouchard",
                jersey: "2",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -1, penaltyMinutes: 0,
                    shots: 2, hits: 1, blockedShots: 1, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 867, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 18
                )
            ),
        ],
        goalies: [
            NHLGoalieLine(
                id: "edm_g1",
                name: "Stuart Skinner",
                jersey: "74",
                stats: NHLGoalieStats(
                    saves: 19, shotsAgainst: 22, goalsAgainst: 3,
                    timeOnIceSeconds: 2400, evenStrengthSaves: 15,
                    powerPlaySaves: 2, shortHandedSaves: 2,
                    evenStrengthShotsAgainst: 17, powerPlayShotsAgainst: 3,
                    shortHandedShotsAgainst: 2
                ),
                decision: nil
            ),
        ],
        teamTotals: NHLTeamTotals(
            goals: 3, assists: 3, shots: 21, hits: 12, blockedShots: 6,
            penaltyMinutes: 4, faceoffWins: 18, faceoffLosses: 15,
            powerPlayGoals: 1, powerPlayOpportunities: 2, shortHandedGoals: 0,
            takeaways: 3, giveaways: 6
        ),
        scratches: []
    )
    
    static let game2 = Game(
        id: "nhl_2",
        sport: .nhl,
        gameDate: dateOffset(0), // Today
        status: .live(period: "2nd", clock: "8:45"),
        awayTeam: avalanche,
        homeTeam: oilers,
        awayScore: 3,
        homeScore: 3,
        awayBoxScore: .nhl(avalancheBoxScore),
        homeBoxScore: .nhl(oilersBoxScore),
        venue: Venue(id: "rogers", name: "Rogers Place", city: "Edmonton", state: "AB")
    )
    
    // MARK: - Game 3: Maple Leafs vs Panthers (Final OT)
    
    static let mapleLeafsBoxScore = NHLTeamBoxScore(
        teamId: "tor",
        teamName: "Maple Leafs",
        skaters: [
            NHLSkaterLine(
                id: "tor_1",
                name: "Auston Matthews",
                jersey: "34",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 2, assists: 0, plusMinus: 1, penaltyMinutes: 0,
                    shots: 7, hits: 1, blockedShots: 0, faceoffWins: 12, faceoffLosses: 9,
                    timeOnIceSeconds: 1423, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 29
                )
            ),
            NHLSkaterLine(
                id: "tor_2",
                name: "Mitch Marner",
                jersey: "16",
                position: "RW",
                stats: NHLSkaterStats(
                    goals: 0, assists: 3, plusMinus: 1, penaltyMinutes: 0,
                    shots: 3, hits: 0, blockedShots: 1, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1389, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 2, shortHandedAssists: 0, shifts: 28
                )
            ),
            NHLSkaterLine(
                id: "tor_3",
                name: "William Nylander",
                jersey: "88",
                position: "RW",
                stats: NHLSkaterStats(
                    goals: 1, assists: 1, plusMinus: 0, penaltyMinutes: 0,
                    shots: 4, hits: 0, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1256, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 26
                )
            ),
            NHLSkaterLine(
                id: "tor_4",
                name: "Morgan Rielly",
                jersey: "44",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: -1, penaltyMinutes: 0,
                    shots: 2, hits: 2, blockedShots: 2, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1534, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 31
                )
            ),
            NHLSkaterLine(
                id: "tor_5",
                name: "John Tavares",
                jersey: "91",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -1, penaltyMinutes: 2,
                    shots: 2, hits: 1, blockedShots: 0, faceoffWins: 9, faceoffLosses: 11,
                    timeOnIceSeconds: 1167, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 25
                )
            ),
        ],
        goalies: [
            NHLGoalieLine(
                id: "tor_g1",
                name: "Ilya Samsonov",
                jersey: "35",
                stats: NHLGoalieStats(
                    saves: 32, shotsAgainst: 36, goalsAgainst: 4,
                    timeOnIceSeconds: 3912, evenStrengthSaves: 27,
                    powerPlaySaves: 3, shortHandedSaves: 2,
                    evenStrengthShotsAgainst: 30, powerPlayShotsAgainst: 4,
                    shortHandedShotsAgainst: 2
                ),
                decision: "OTL"
            ),
        ],
        teamTotals: NHLTeamTotals(
            goals: 3, assists: 5, shots: 34, hits: 18, blockedShots: 12,
            penaltyMinutes: 6, faceoffWins: 28, faceoffLosses: 32,
            powerPlayGoals: 2, powerPlayOpportunities: 5, shortHandedGoals: 0,
            takeaways: 5, giveaways: 9
        ),
        scratches: []
    )
    
    static let panthersBoxScore = NHLTeamBoxScore(
        teamId: "fla",
        teamName: "Panthers",
        skaters: [
            NHLSkaterLine(
                id: "fla_1",
                name: "Aleksander Barkov",
                jersey: "16",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 2, plusMinus: 1, penaltyMinutes: 0,
                    shots: 5, hits: 1, blockedShots: 1, faceoffWins: 15, faceoffLosses: 11,
                    timeOnIceSeconds: 1456, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 1, shortHandedAssists: 0, shifts: 30
                )
            ),
            NHLSkaterLine(
                id: "fla_2",
                name: "Matthew Tkachuk",
                jersey: "19",
                position: "LW",
                stats: NHLSkaterStats(
                    goals: 2, assists: 1, plusMinus: 2, penaltyMinutes: 4,
                    shots: 6, hits: 4, blockedShots: 0, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1389, powerPlayGoals: 1, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 28
                )
            ),
            NHLSkaterLine(
                id: "fla_3",
                name: "Sam Reinhart",
                jersey: "13",
                position: "C",
                stats: NHLSkaterStats(
                    goals: 1, assists: 0, plusMinus: 0, penaltyMinutes: 0,
                    shots: 4, hits: 1, blockedShots: 0, faceoffWins: 8, faceoffLosses: 7,
                    timeOnIceSeconds: 1234, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 26
                )
            ),
            NHLSkaterLine(
                id: "fla_4",
                name: "Gustav Forsling",
                jersey: "42",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 1, plusMinus: 1, penaltyMinutes: 0,
                    shots: 2, hits: 3, blockedShots: 4, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1512, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 31
                )
            ),
            NHLSkaterLine(
                id: "fla_5",
                name: "Aaron Ekblad",
                jersey: "5",
                position: "D",
                stats: NHLSkaterStats(
                    goals: 0, assists: 0, plusMinus: -1, penaltyMinutes: 2,
                    shots: 1, hits: 4, blockedShots: 3, faceoffWins: 0, faceoffLosses: 0,
                    timeOnIceSeconds: 1423, powerPlayGoals: 0, shortHandedGoals: 0,
                    powerPlayAssists: 0, shortHandedAssists: 0, shifts: 29
                )
            ),
        ],
        goalies: [
            NHLGoalieLine(
                id: "fla_g1",
                name: "Sergei Bobrovsky",
                jersey: "72",
                stats: NHLGoalieStats(
                    saves: 31, shotsAgainst: 34, goalsAgainst: 3,
                    timeOnIceSeconds: 3912, evenStrengthSaves: 25,
                    powerPlaySaves: 4, shortHandedSaves: 2,
                    evenStrengthShotsAgainst: 27, powerPlayShotsAgainst: 5,
                    shortHandedShotsAgainst: 2
                ),
                decision: "W"
            ),
        ],
        teamTotals: NHLTeamTotals(
            goals: 4, assists: 4, shots: 36, hits: 22, blockedShots: 14,
            penaltyMinutes: 8, faceoffWins: 32, faceoffLosses: 28,
            powerPlayGoals: 1, powerPlayOpportunities: 3, shortHandedGoals: 0,
            takeaways: 7, giveaways: 6
        ),
        scratches: []
    )
    
    static let game3 = Game(
        id: "nhl_3",
        sport: .nhl,
        gameDate: dateOffset(-1), // Yesterday
        status: .finalOvertime(periods: 1),
        awayTeam: maple_leafs,
        homeTeam: panthers,
        awayScore: 3,
        homeScore: 4,
        awayBoxScore: .nhl(mapleLeafsBoxScore),
        homeBoxScore: .nhl(panthersBoxScore),
        venue: Venue(id: "amerant", name: "Amerant Bank Arena", city: "Sunrise", state: "FL")
    )
    
    // MARK: - All Games
    
    static let allGames: [Game] = [game1, game2, game3]
}
