-- Migration: NFL Player Stats System
-- Adds tables for NFL player statistics, game logs, and career summaries
-- Uses JSONB for flexible position-based stats (QB, RB, WR, TE, Defense vary significantly)

-- =====================
-- NFL PLAYER SEASON SUMMARY
-- Precomputed season aggregates per player
-- Uses JSONB for position-specific stats
-- =====================

CREATE TABLE IF NOT EXISTS nfl_player_season_summary (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,                    -- e.g., 2025 for 2025 season
    team_id VARCHAR(100),                       -- NULL for "TOTAL" across all teams

    -- Common fields
    games_played INTEGER DEFAULT 0,
    games_started INTEGER DEFAULT 0,

    -- Position category for UI rendering
    position_category VARCHAR(20),              -- 'QB', 'RB', 'WR', 'TE', 'DEF', 'K'

    -- Flexible stats storage (structure varies by position)
    -- QB: passing_yards, passing_tds, interceptions, completions, attempts, passer_rating, rushing_yards, rushing_tds
    -- RB: rushing_yards, rushing_tds, carries, avg_yards, receiving_yards, receptions, receiving_tds
    -- WR/TE: receptions, targets, receiving_yards, receiving_tds, avg_yards, yards_after_catch
    -- DEF: total_tackles, solo_tackles, assisted_tackles, sacks, interceptions, forced_fumbles, fumble_recoveries
    -- K: field_goals_made, field_goals_attempted, extra_points_made, extra_points_attempted, long_fg
    stats_json JSONB NOT NULL DEFAULT '{}',

    -- Metadata
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE (player_id, season, team_id)
);

CREATE INDEX IF NOT EXISTS idx_nfl_season_summary_player ON nfl_player_season_summary(player_id);
CREATE INDEX IF NOT EXISTS idx_nfl_season_summary_season ON nfl_player_season_summary(season);
CREATE INDEX IF NOT EXISTS idx_nfl_season_summary_position ON nfl_player_season_summary(position_category);
CREATE INDEX IF NOT EXISTS idx_nfl_season_summary_stats ON nfl_player_season_summary USING gin (stats_json);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nfl_season_summary_updated_at ON nfl_player_season_summary;
CREATE TRIGGER update_nfl_season_summary_updated_at
    BEFORE UPDATE ON nfl_player_season_summary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- NFL PLAYER GAME LOGS
-- Individual game performance records
-- =====================

CREATE TABLE IF NOT EXISTS nfl_player_game_logs (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    game_id VARCHAR(100) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,
    week INTEGER,                               -- NFL week number (1-18, playoffs)
    game_date DATE NOT NULL,
    team_id VARCHAR(100),
    opponent_team_id VARCHAR(100),
    is_home BOOLEAN,
    is_starter BOOLEAN DEFAULT false,

    -- Position category
    position_category VARCHAR(20),

    -- Flexible stats (same structure as season summary)
    stats_json JSONB NOT NULL DEFAULT '{}',

    -- Metadata
    dnp_reason VARCHAR(200),                    -- "Did Not Play" reason if applicable
    updated_at TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (player_id, game_id)
);

CREATE INDEX IF NOT EXISTS idx_nfl_game_logs_player_season ON nfl_player_game_logs(player_id, season);
CREATE INDEX IF NOT EXISTS idx_nfl_game_logs_game_date ON nfl_player_game_logs(player_id, season, game_date DESC);
CREATE INDEX IF NOT EXISTS idx_nfl_game_logs_game ON nfl_player_game_logs(game_id);
CREATE INDEX IF NOT EXISTS idx_nfl_game_logs_week ON nfl_player_game_logs(season, week);
CREATE INDEX IF NOT EXISTS idx_nfl_game_logs_stats ON nfl_player_game_logs USING gin (stats_json);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nfl_game_logs_updated_at ON nfl_player_game_logs;
CREATE TRIGGER update_nfl_game_logs_updated_at
    BEFORE UPDATE ON nfl_player_game_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- NFL PLAYER CAREER SUMMARY
-- Historical season-by-season career stats
-- =====================

CREATE TABLE IF NOT EXISTS nfl_player_career_summary (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,
    team_id VARCHAR(100),                       -- NULL for "TOTAL" if played for multiple teams

    -- Common fields
    games_played INTEGER DEFAULT 0,
    games_started INTEGER DEFAULT 0,

    -- Position category
    position_category VARCHAR(20),

    -- Flexible stats storage
    stats_json JSONB NOT NULL DEFAULT '{}',

    -- Metadata
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE (player_id, season, team_id)
);

CREATE INDEX IF NOT EXISTS idx_nfl_career_player ON nfl_player_career_summary(player_id);
CREATE INDEX IF NOT EXISTS idx_nfl_career_season ON nfl_player_career_summary(season);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nfl_career_updated_at ON nfl_player_career_summary;
CREATE TRIGGER update_nfl_career_updated_at
    BEFORE UPDATE ON nfl_player_career_summary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- COMMENTS
-- =====================

COMMENT ON TABLE nfl_player_season_summary IS 'Precomputed season aggregates for NFL players. Uses JSONB for position-specific stats.';
COMMENT ON TABLE nfl_player_game_logs IS 'Individual game performance logs for NFL players. Uses JSONB for position-specific stats.';
COMMENT ON TABLE nfl_player_career_summary IS 'Career historical season-by-season summaries for NFL players.';

COMMENT ON COLUMN nfl_player_season_summary.position_category IS 'Position category for UI rendering: QB, RB, WR, TE, DEF, K';
COMMENT ON COLUMN nfl_player_season_summary.stats_json IS 'Position-specific stats. QB: passing/rushing, RB: rushing/receiving, WR/TE: receiving, DEF: tackles/sacks/ints';
