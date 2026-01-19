//
//  NFLMockData.swift
//  BoxScore
//
//  Mock NFL game data for development
//

import Foundation

enum NFLMockData {
    
    // MARK: - Teams
    
    static let chiefs = TeamInfo(
        id: "kc",
        abbreviation: "KC",
        name: "Chiefs",
        city: "Kansas City",
        primaryColor: "#E31837"
    )
    
    static let eagles = TeamInfo(
        id: "phi",
        abbreviation: "PHI",
        name: "Eagles",
        city: "Philadelphia",
        primaryColor: "#004C54"
    )
    
    static let niners = TeamInfo(
        id: "sf",
        abbreviation: "SF",
        name: "49ers",
        city: "San Francisco",
        primaryColor: "#AA0000"
    )
    
    static let cowboys = TeamInfo(
        id: "dal",
        abbreviation: "DAL",
        name: "Cowboys",
        city: "Dallas",
        primaryColor: "#003594"
    )
    
    // MARK: - Helper Functions
    
    static func createPassingSection(teamId: String, rows: [TableRow], teamTotals: TableRow?) -> NFLSection {
        NFLSection(
            id: "\(teamId)_passing",
            type: .passing,
            columns: NFLColumns.passing,
            rows: rows,
            teamTotalsRow: teamTotals
        )
    }
    
    static func createRushingSection(teamId: String, rows: [TableRow], teamTotals: TableRow?) -> NFLSection {
        NFLSection(
            id: "\(teamId)_rushing",
            type: .rushing,
            columns: NFLColumns.rushing,
            rows: rows,
            teamTotalsRow: teamTotals
        )
    }
    
    static func createReceivingSection(teamId: String, rows: [TableRow], teamTotals: TableRow?) -> NFLSection {
        NFLSection(
            id: "\(teamId)_receiving",
            type: .receiving,
            columns: NFLColumns.receiving,
            rows: rows,
            teamTotalsRow: teamTotals
        )
    }
    
    static func createTacklesSection(teamId: String, rows: [TableRow], teamTotals: TableRow?) -> NFLSection {
        NFLSection(
            id: "\(teamId)_tackles",
            type: .tackles,
            columns: NFLColumns.tackles,
            rows: rows,
            teamTotalsRow: teamTotals
        )
    }
    
    static func createKickingSection(teamId: String, rows: [TableRow]) -> NFLSection {
        NFLSection(
            id: "\(teamId)_kicking",
            type: .kicking,
            columns: NFLColumns.kicking,
            rows: rows
        )
    }
    
    static func createPuntingSection(teamId: String, rows: [TableRow]) -> NFLSection {
        NFLSection(
            id: "\(teamId)_punting",
            type: .punting,
            columns: NFLColumns.punting,
            rows: rows
        )
    }
    
    static func createKickReturnsSection(teamId: String, rows: [TableRow], teamTotals: TableRow?) -> NFLSection {
        NFLSection(
            id: "\(teamId)_kickreturns",
            type: .kickReturns,
            columns: NFLColumns.kickReturns,
            rows: rows,
            teamTotalsRow: teamTotals
        )
    }
    
    static func createPuntReturnsSection(teamId: String, rows: [TableRow], teamTotals: TableRow?) -> NFLSection {
        NFLSection(
            id: "\(teamId)_puntreturns",
            type: .puntReturns,
            columns: NFLColumns.puntReturns,
            rows: rows,
            teamTotalsRow: teamTotals
        )
    }
    
    // MARK: - Game 1: Chiefs vs Eagles (Final)
    
    static let chiefsBoxScore: NFLTeamBoxScore = {
        let teamId = "kc"
        
        // OFFENSE
        let passing = createPassingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_mahomes", leadingText: "P. Mahomes", subtitle: "#15", cells: ["28", "42", "324", "3", "1", "2", "108.5"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_passing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["28", "42", "324", "3", "1", "2", "108.5"])
        )
        
        let rushing = createRushingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_pacheco", leadingText: "I. Pacheco", subtitle: "#10", cells: ["18", "92", "5.1", "1", "23"]),
                TableRow(id: "\(teamId)_mahomes_rush", leadingText: "P. Mahomes", subtitle: "#15", cells: ["4", "28", "7.0", "0", "15"]),
                TableRow(id: "\(teamId)_mckinnon", leadingText: "J. McKinnon", subtitle: "#1", cells: ["6", "21", "3.5", "0", "8"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_rushing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["28", "141", "5.0", "1", "23"])
        )
        
        let receiving = createReceivingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_kelce", leadingText: "T. Kelce", subtitle: "#87", cells: ["9", "12", "98", "10.9", "1", "24"]),
                TableRow(id: "\(teamId)_smith", leadingText: "J. Smith-Schuster", subtitle: "#9", cells: ["7", "9", "89", "12.7", "1", "32"]),
                TableRow(id: "\(teamId)_rice", leadingText: "R. Rice", subtitle: "#4", cells: ["5", "8", "68", "13.6", "0", "28"]),
                TableRow(id: "\(teamId)_watson", leadingText: "J. Watson", subtitle: "#84", cells: ["4", "6", "42", "10.5", "1", "18"]),
                TableRow(id: "\(teamId)_pacheco_rec", leadingText: "I. Pacheco", subtitle: "#10", cells: ["3", "5", "27", "9.0", "0", "12"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_receiving_team", isTeamTotals: true, leadingText: "TEAM", cells: ["28", "42", "324", "11.6", "3", "32"])
        )
        
        let offense = NFLGroup(
            id: "\(teamId)_offense",
            type: .offense,
            sections: [passing, rushing, receiving]
        )
        
        // DEFENSE
        let tackles = createTacklesSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_sneed", leadingText: "L. Sneed", subtitle: "#38", cells: ["8", "6", "2", "1", "0"]),
                TableRow(id: "\(teamId)_bolton", leadingText: "N. Bolton", subtitle: "#32", cells: ["7", "4", "3", "0", "1"]),
                TableRow(id: "\(teamId)_reid", leadingText: "J. Reid", subtitle: "#35", cells: ["6", "5", "1", "0", "0"]),
                TableRow(id: "\(teamId)_jones", leadingText: "C. Jones", subtitle: "#95", cells: ["4", "3", "1", "2", "2"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_tackles_team", isTeamTotals: true, leadingText: "TEAM", cells: ["58", "42", "16", "5", "4"])
        )
        
        let interceptions = NFLSection(
            id: "\(teamId)_interceptions",
            type: .interceptions,
            columns: NFLColumns.interceptions,
            rows: [
                TableRow(id: "\(teamId)_sneed_int", leadingText: "L. Sneed", subtitle: "#38", cells: ["1", "32", "0"]),
            ]
        )
        
        let defense = NFLGroup(
            id: "\(teamId)_defense",
            type: .defense,
            sections: [tackles, interceptions]
        )
        
        // SPECIAL TEAMS
        let kicking = createKickingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_butker", leadingText: "H. Butker", subtitle: "#7", cells: ["2", "3", "48", "4", "4", "10"]),
            ]
        )
        
        let punting = createPuntingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_townsend", leadingText: "T. Townsend", subtitle: "#5", cells: ["3", "142", "47.3", "0", "2", "54"]),
            ]
        )
        
        let kickReturns = NFLSection.empty(type: .kickReturns, teamId: teamId)
        
        let puntReturns = createPuntReturnsSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_hardman", leadingText: "M. Hardman", subtitle: "#17", cells: ["2", "18", "9.0", "0", "12"]),
            ],
            teamTotals: nil
        )
        
        let specialTeams = NFLGroup(
            id: "\(teamId)_special",
            type: .specialTeams,
            sections: [kicking, punting, kickReturns, puntReturns]
        )
        
        return NFLTeamBoxScore(
            teamId: teamId,
            teamName: "Chiefs",
            groups: [offense, defense, specialTeams]
        )
    }()
    
    static let eaglesBoxScore: NFLTeamBoxScore = {
        let teamId = "phi"
        
        // OFFENSE
        let passing = createPassingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_hurts", leadingText: "J. Hurts", subtitle: "#1", cells: ["24", "38", "286", "2", "1", "3", "94.2"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_passing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["24", "38", "286", "2", "1", "3", "94.2"])
        )
        
        let rushing = createRushingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_sanders", leadingText: "M. Sanders", subtitle: "#26", cells: ["15", "78", "5.2", "1", "18"]),
                TableRow(id: "\(teamId)_hurts_rush", leadingText: "J. Hurts", subtitle: "#1", cells: ["8", "42", "5.3", "1", "12"]),
                TableRow(id: "\(teamId)_scott", leadingText: "B. Scott", subtitle: "#35", cells: ["4", "16", "4.0", "0", "7"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_rushing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["27", "136", "5.0", "2", "18"])
        )
        
        let receiving = createReceivingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_brown", leadingText: "A.J. Brown", subtitle: "#11", cells: ["8", "11", "112", "14.0", "1", "38"]),
                TableRow(id: "\(teamId)_smith", leadingText: "D. Smith", subtitle: "#6", cells: ["6", "10", "78", "13.0", "0", "22"]),
                TableRow(id: "\(teamId)_goedert", leadingText: "D. Goedert", subtitle: "#88", cells: ["5", "8", "56", "11.2", "1", "18"]),
                TableRow(id: "\(teamId)_sanders_rec", leadingText: "M. Sanders", subtitle: "#26", cells: ["4", "6", "32", "8.0", "0", "14"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_receiving_team", isTeamTotals: true, leadingText: "TEAM", cells: ["24", "38", "286", "11.9", "2", "38"])
        )
        
        let offense = NFLGroup(
            id: "\(teamId)_offense",
            type: .offense,
            sections: [passing, rushing, receiving]
        )
        
        // DEFENSE
        let tackles = createTacklesSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_edwards", leadingText: "T.J. Edwards", subtitle: "#57", cells: ["10", "7", "3", "1", "0"]),
                TableRow(id: "\(teamId)_bradberry", leadingText: "J. Bradberry", subtitle: "#24", cells: ["6", "5", "1", "0", "1"]),
                TableRow(id: "\(teamId)_slay", leadingText: "D. Slay", subtitle: "#2", cells: ["5", "4", "1", "0", "0"]),
                TableRow(id: "\(teamId)_reddick", leadingText: "H. Reddick", subtitle: "#7", cells: ["4", "3", "1", "1", "2"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_tackles_team", isTeamTotals: true, leadingText: "TEAM", cells: ["52", "38", "14", "4", "5"])
        )
        
        let sacks = NFLSection(
            id: "\(teamId)_sacks",
            type: .sacks,
            columns: NFLColumns.sacks,
            rows: [
                TableRow(id: "\(teamId)_reddick_sack", leadingText: "H. Reddick", subtitle: "#7", cells: ["1.5", "12"]),
                TableRow(id: "\(teamId)_graham", leadingText: "B. Graham", subtitle: "#55", cells: ["1.0", "8"]),
            ]
        )
        
        let defense = NFLGroup(
            id: "\(teamId)_defense",
            type: .defense,
            sections: [tackles, sacks]
        )
        
        // SPECIAL TEAMS
        let kicking = createKickingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_elliott", leadingText: "J. Elliott", subtitle: "#4", cells: ["1", "2", "42", "3", "3", "6"]),
            ]
        )
        
        let punting = createPuntingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_siposs", leadingText: "A. Siposs", subtitle: "#8", cells: ["4", "176", "44.0", "1", "2", "52"]),
            ]
        )
        
        let kickReturns = createKickReturnsSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_covey", leadingText: "B. Covey", subtitle: "#18", cells: ["2", "48", "24.0", "0", "28"]),
            ],
            teamTotals: nil
        )
        
        let puntReturns = NFLSection.empty(type: .puntReturns, teamId: teamId)
        
        let specialTeams = NFLGroup(
            id: "\(teamId)_special",
            type: .specialTeams,
            sections: [kicking, punting, kickReturns, puntReturns]
        )
        
        return NFLTeamBoxScore(
            teamId: teamId,
            teamName: "Eagles",
            groups: [offense, defense, specialTeams]
        )
    }()
    
    // Helper to create dates relative to today
    private static func dateOffset(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: Date()))!
    }
    
    static let game1 = Game(
        id: "nfl_1",
        sport: .nfl,
        gameDate: dateOffset(0), // Today
        status: .final,
        awayTeam: chiefs,
        homeTeam: eagles,
        awayScore: 38,
        homeScore: 35,
        awayBoxScore: .nfl(chiefsBoxScore),
        homeBoxScore: .nfl(eaglesBoxScore)
    )
    
    // MARK: - Game 2: 49ers vs Cowboys (Live)
    
    static let ninersBoxScore: NFLTeamBoxScore = {
        let teamId = "sf"
        
        // OFFENSE
        let passing = createPassingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_purdy", leadingText: "B. Purdy", subtitle: "#13", cells: ["18", "24", "212", "2", "0", "1", "128.8"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_passing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["18", "24", "212", "2", "0", "1", "128.8"])
        )
        
        let rushing = createRushingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_mccaffrey", leadingText: "C. McCaffrey", subtitle: "#23", cells: ["12", "68", "5.7", "1", "22"]),
                TableRow(id: "\(teamId)_mitchell", leadingText: "E. Mitchell", subtitle: "#25", cells: ["6", "32", "5.3", "0", "11"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_rushing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["18", "100", "5.6", "1", "22"])
        )
        
        let receiving = createReceivingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_samuel", leadingText: "D. Samuel", subtitle: "#19", cells: ["6", "7", "82", "13.7", "1", "32"]),
                TableRow(id: "\(teamId)_aiyuk", leadingText: "B. Aiyuk", subtitle: "#11", cells: ["5", "7", "68", "13.6", "0", "24"]),
                TableRow(id: "\(teamId)_mccaffrey_rec", leadingText: "C. McCaffrey", subtitle: "#23", cells: ["4", "5", "38", "9.5", "1", "15"]),
                TableRow(id: "\(teamId)_kittle", leadingText: "G. Kittle", subtitle: "#85", cells: ["3", "5", "24", "8.0", "0", "12"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_receiving_team", isTeamTotals: true, leadingText: "TEAM", cells: ["18", "24", "212", "11.8", "2", "32"])
        )
        
        let offense = NFLGroup(
            id: "\(teamId)_offense",
            type: .offense,
            sections: [passing, rushing, receiving]
        )
        
        // DEFENSE
        let tackles = createTacklesSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_warner", leadingText: "F. Warner", subtitle: "#54", cells: ["6", "4", "2", "1", "0"]),
                TableRow(id: "\(teamId)_greenlaw", leadingText: "D. Greenlaw", subtitle: "#57", cells: ["5", "4", "1", "0", "1"]),
                TableRow(id: "\(teamId)_bosa", leadingText: "N. Bosa", subtitle: "#97", cells: ["3", "2", "1", "1", "2"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_tackles_team", isTeamTotals: true, leadingText: "TEAM", cells: ["32", "24", "8", "3", "4"])
        )
        
        let defense = NFLGroup(
            id: "\(teamId)_defense",
            type: .defense,
            sections: [tackles]
        )
        
        // SPECIAL TEAMS
        let kicking = createKickingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_gould", leadingText: "R. Gould", subtitle: "#9", cells: ["1", "1", "38", "3", "3", "6"]),
            ]
        )
        
        let specialTeams = NFLGroup(
            id: "\(teamId)_special",
            type: .specialTeams,
            sections: [kicking]
        )
        
        return NFLTeamBoxScore(
            teamId: teamId,
            teamName: "49ers",
            groups: [offense, defense, specialTeams]
        )
    }()
    
    static let cowboysBoxScore: NFLTeamBoxScore = {
        let teamId = "dal"
        
        // OFFENSE
        let passing = createPassingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_prescott", leadingText: "D. Prescott", subtitle: "#4", cells: ["14", "22", "168", "1", "1", "2", "78.4"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_passing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["14", "22", "168", "1", "1", "2", "78.4"])
        )
        
        let rushing = createRushingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_pollard", leadingText: "T. Pollard", subtitle: "#20", cells: ["8", "42", "5.3", "0", "14"]),
                TableRow(id: "\(teamId)_prescott_rush", leadingText: "D. Prescott", subtitle: "#4", cells: ["2", "8", "4.0", "0", "6"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_rushing_team", isTeamTotals: true, leadingText: "TEAM", cells: ["10", "50", "5.0", "0", "14"])
        )
        
        let receiving = createReceivingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_lamb", leadingText: "C. Lamb", subtitle: "#88", cells: ["5", "8", "72", "14.4", "1", "28"]),
                TableRow(id: "\(teamId)_ferguson", leadingText: "J. Ferguson", subtitle: "#87", cells: ["4", "6", "48", "12.0", "0", "18"]),
                TableRow(id: "\(teamId)_wilson", leadingText: "M. Wilson", subtitle: "#18", cells: ["3", "5", "32", "10.7", "0", "15"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_receiving_team", isTeamTotals: true, leadingText: "TEAM", cells: ["14", "22", "168", "12.0", "1", "28"])
        )
        
        let offense = NFLGroup(
            id: "\(teamId)_offense",
            type: .offense,
            sections: [passing, rushing, receiving]
        )
        
        // DEFENSE
        let tackles = createTacklesSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_parsons", leadingText: "M. Parsons", subtitle: "#11", cells: ["5", "3", "2", "2", "3"]),
                TableRow(id: "\(teamId)_diggs", leadingText: "T. Diggs", subtitle: "#7", cells: ["4", "3", "1", "0", "0"]),
                TableRow(id: "\(teamId)_vander", leadingText: "L. Vander Esch", subtitle: "#55", cells: ["4", "3", "1", "0", "0"]),
            ],
            teamTotals: TableRow(id: "\(teamId)_tackles_team", isTeamTotals: true, leadingText: "TEAM", cells: ["28", "20", "8", "3", "4"])
        )
        
        let interceptions = NFLSection(
            id: "\(teamId)_interceptions",
            type: .interceptions,
            columns: NFLColumns.interceptions,
            rows: []  // Empty - no interceptions yet
        )
        
        let defense = NFLGroup(
            id: "\(teamId)_defense",
            type: .defense,
            sections: [tackles, interceptions]
        )
        
        // SPECIAL TEAMS
        let kicking = createKickingSection(
            teamId: teamId,
            rows: [
                TableRow(id: "\(teamId)_maher", leadingText: "B. Maher", subtitle: "#19", cells: ["0", "1", "0", "2", "2", "2"]),
            ]
        )
        
        let specialTeams = NFLGroup(
            id: "\(teamId)_special",
            type: .specialTeams,
            sections: [kicking]
        )
        
        return NFLTeamBoxScore(
            teamId: teamId,
            teamName: "Cowboys",
            groups: [offense, defense, specialTeams]
        )
    }()
    
    static let game2 = Game(
        id: "nfl_2",
        sport: .nfl,
        gameDate: dateOffset(0), // Today
        status: .live(period: "3RD", clock: "8:42"),
        awayTeam: niners,
        homeTeam: cowboys,
        awayScore: 24,
        homeScore: 17,
        awayBoxScore: .nfl(ninersBoxScore),
        homeBoxScore: .nfl(cowboysBoxScore)
    )
    
    // MARK: - All Games
    
    static let allGames: [Game] = [game1, game2]
}

