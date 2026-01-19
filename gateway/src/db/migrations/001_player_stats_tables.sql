-- Migration: Player Stats System for Player Pages
-- Adds tables for player statistics, game logs, splits, and career summaries
-- NBA v1 implementation

-- =====================
-- ENHANCE PLAYERS TABLE
-- Add fields needed for player pages
-- =====================

-- Add new columns to existing players table
ALTER TABLE players
    ADD COLUMN IF NOT EXISTS sport VARCHAR(20),
    ADD COLUMN IF NOT EXISTS display_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS height_in INTEGER,
    ADD COLUMN IF NOT EXISTS weight_lb INTEGER,
    ADD COLUMN IF NOT EXISTS school VARCHAR(200),
    ADD COLUMN IF NOT EXISTS hometown VARCHAR(200),
    ADD COLUMN IF NOT EXISTS headshot_url TEXT,
    ADD COLUMN IF NOT EXISTS current_team_id VARCHAR(100),
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Create index on sport for filtering
CREATE INDEX IF NOT EXISTS idx_players_sport ON players(sport);
CREATE INDEX IF NOT EXISTS idx_players_current_team ON players(current_team_id);

-- Update existing display_name from name if null
UPDATE players SET display_name = name WHERE display_name IS NULL;

-- =====================
-- PLAYER PROVIDER MAPPING
-- Already exists as external_ids table, but add specific index
-- =====================

CREATE INDEX IF NOT EXISTS idx_external_ids_player_lookup
    ON external_ids(entity_type, provider, provider_id)
    WHERE entity_type = 'player';

-- =====================
-- NBA PLAYER SEASON SUMMARY
-- Precomputed season aggregates per player
-- =====================

CREATE TABLE IF NOT EXISTS nba_player_season_summary (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,                    -- e.g., 2025 for 2025-26 season
    team_id VARCHAR(100),                       -- NULL for "TOTAL" across all teams

    -- Games played
    games_played INTEGER DEFAULT 0,
    games_started INTEGER DEFAULT 0,

    -- Time
    minutes_total NUMERIC(10,1) DEFAULT 0,      -- Total minutes played

    -- Scoring
    points_total INTEGER DEFAULT 0,

    -- Shooting
    fgm INTEGER DEFAULT 0,                      -- Field goals made
    fga INTEGER DEFAULT 0,                      -- Field goals attempted
    fg3m INTEGER DEFAULT 0,                     -- Three pointers made
    fg3a INTEGER DEFAULT 0,                     -- Three pointers attempted
    ftm INTEGER DEFAULT 0,                      -- Free throws made
    fta INTEGER DEFAULT 0,                      -- Free throws attempted

    -- Rebounding
    oreb INTEGER DEFAULT 0,                     -- Offensive rebounds
    dreb INTEGER DEFAULT 0,                     -- Defensive rebounds
    reb INTEGER DEFAULT 0,                      -- Total rebounds

    -- Playmaking & Defense
    ast INTEGER DEFAULT 0,                      -- Assists
    stl INTEGER DEFAULT 0,                      -- Steals
    blk INTEGER DEFAULT 0,                      -- Blocks
    tov INTEGER DEFAULT 0,                      -- Turnovers

    -- Fouls
    pf INTEGER DEFAULT 0,                       -- Personal fouls

    -- Derived percentages (computed for convenience)
    fg_pct NUMERIC(5,3),                        -- Field goal percentage
    fg3_pct NUMERIC(5,3),                       -- Three point percentage
    ft_pct NUMERIC(5,3),                        -- Free throw percentage

    -- Per game averages (computed for convenience)
    ppg NUMERIC(5,1),                           -- Points per game
    rpg NUMERIC(5,1),                           -- Rebounds per game
    apg NUMERIC(5,1),                           -- Assists per game

    -- Metadata
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE (player_id, season, team_id)
);

CREATE INDEX IF NOT EXISTS idx_nba_season_summary_player ON nba_player_season_summary(player_id);
CREATE INDEX IF NOT EXISTS idx_nba_season_summary_season ON nba_player_season_summary(season);
CREATE INDEX IF NOT EXISTS idx_nba_season_summary_team ON nba_player_season_summary(team_id);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nba_season_summary_updated_at ON nba_player_season_summary;
CREATE TRIGGER update_nba_season_summary_updated_at
    BEFORE UPDATE ON nba_player_season_summary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- NBA PLAYER GAME LOGS
-- Individual game performance records
-- =====================

CREATE TABLE IF NOT EXISTS nba_player_game_logs (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    game_id VARCHAR(100) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,
    game_date DATE NOT NULL,
    team_id VARCHAR(100),
    opponent_team_id VARCHAR(100),
    is_home BOOLEAN,
    is_starter BOOLEAN DEFAULT false,

    -- Time
    minutes NUMERIC(5,1),                       -- Minutes played (can be fractional)

    -- Scoring
    points INTEGER DEFAULT 0,

    -- Shooting
    fgm INTEGER DEFAULT 0,
    fga INTEGER DEFAULT 0,
    fg3m INTEGER DEFAULT 0,
    fg3a INTEGER DEFAULT 0,
    ftm INTEGER DEFAULT 0,
    fta INTEGER DEFAULT 0,

    -- Rebounding
    oreb INTEGER DEFAULT 0,
    dreb INTEGER DEFAULT 0,
    reb INTEGER DEFAULT 0,

    -- Playmaking & Defense
    ast INTEGER DEFAULT 0,
    stl INTEGER DEFAULT 0,
    blk INTEGER DEFAULT 0,
    tov INTEGER DEFAULT 0,

    -- Fouls
    pf INTEGER DEFAULT 0,

    -- Plus/minus
    plus_minus INTEGER,

    -- Derived
    fg_pct NUMERIC(5,3),
    fg3_pct NUMERIC(5,3),
    ft_pct NUMERIC(5,3),

    -- Metadata
    dnp_reason VARCHAR(200),                    -- "Did Not Play" reason if applicable
    updated_at TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (player_id, game_id)
);

CREATE INDEX IF NOT EXISTS idx_nba_game_logs_player_season ON nba_player_game_logs(player_id, season);
CREATE INDEX IF NOT EXISTS idx_nba_game_logs_game_date ON nba_player_game_logs(player_id, season, game_date DESC);
CREATE INDEX IF NOT EXISTS idx_nba_game_logs_game ON nba_player_game_logs(game_id);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nba_game_logs_updated_at ON nba_player_game_logs;
CREATE TRIGGER update_nba_game_logs_updated_at
    BEFORE UPDATE ON nba_player_game_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- NBA PLAYER SPLITS
-- Precomputed statistical splits (home/away, monthly, last N games)
-- =====================

CREATE TABLE IF NOT EXISTS nba_player_splits (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,
    split_type VARCHAR(50) NOT NULL,            -- 'HOME_AWAY', 'LAST_N', 'BY_MONTH'
    split_key VARCHAR(50) NOT NULL,             -- 'HOME', 'AWAY', 'LAST5', 'LAST10', 'LAST20', 'OCT', 'NOV', etc.

    -- Precomputed aggregate stats stored as JSONB for flexibility
    stats_json JSONB NOT NULL,                  -- Same structure as season summary

    -- Metadata
    games_included INTEGER DEFAULT 0,           -- How many games contributed to this split
    last_game_date DATE,                        -- Most recent game included in this split
    updated_at TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (player_id, season, split_type, split_key)
);

CREATE INDEX IF NOT EXISTS idx_nba_splits_player_season ON nba_player_splits(player_id, season);
CREATE INDEX IF NOT EXISTS idx_nba_splits_type ON nba_player_splits(split_type);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nba_splits_updated_at ON nba_player_splits;
CREATE TRIGGER update_nba_splits_updated_at
    BEFORE UPDATE ON nba_player_splits
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- NBA PLAYER CAREER SEASON SUMMARY
-- Historical season-by-season career stats
-- =====================

CREATE TABLE IF NOT EXISTS nba_player_career_summary (
    player_id VARCHAR(100) NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    season INTEGER NOT NULL,
    team_id VARCHAR(100),                       -- NULL for "TOTAL" if played for multiple teams

    -- Same fields as nba_player_season_summary
    games_played INTEGER DEFAULT 0,
    games_started INTEGER DEFAULT 0,
    minutes_total NUMERIC(10,1) DEFAULT 0,
    points_total INTEGER DEFAULT 0,

    -- Shooting
    fgm INTEGER DEFAULT 0,
    fga INTEGER DEFAULT 0,
    fg3m INTEGER DEFAULT 0,
    fg3a INTEGER DEFAULT 0,
    ftm INTEGER DEFAULT 0,
    fta INTEGER DEFAULT 0,

    -- Rebounding
    oreb INTEGER DEFAULT 0,
    dreb INTEGER DEFAULT 0,
    reb INTEGER DEFAULT 0,

    -- Playmaking & Defense
    ast INTEGER DEFAULT 0,
    stl INTEGER DEFAULT 0,
    blk INTEGER DEFAULT 0,
    tov INTEGER DEFAULT 0,
    pf INTEGER DEFAULT 0,

    -- Derived
    fg_pct NUMERIC(5,3),
    fg3_pct NUMERIC(5,3),
    ft_pct NUMERIC(5,3),
    ppg NUMERIC(5,1),
    rpg NUMERIC(5,1),
    apg NUMERIC(5,1),

    -- Metadata
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE (player_id, season, team_id)
);

CREATE INDEX IF NOT EXISTS idx_nba_career_player ON nba_player_career_summary(player_id);
CREATE INDEX IF NOT EXISTS idx_nba_career_season ON nba_player_career_summary(season);

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS update_nba_career_updated_at ON nba_player_career_summary;
CREATE TRIGGER update_nba_career_updated_at
    BEFORE UPDATE ON nba_player_career_summary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- TEAM LIVE STATUS
-- Tracks which teams are currently in live games or recently finished
-- Used for cache TTL decisions
-- =====================

CREATE TABLE IF NOT EXISTS team_live_status (
    team_id VARCHAR(100) PRIMARY KEY REFERENCES teams(id) ON DELETE CASCADE,
    is_live BOOLEAN DEFAULT false,              -- Team currently in a live game
    last_game_end_time TIMESTAMP,               -- When their last game ended
    last_checked_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_live_status_live ON team_live_status(is_live) WHERE is_live = true;

-- Trigger to update last_checked_at
DROP TRIGGER IF EXISTS update_team_live_status_checked_at ON team_live_status;
CREATE TRIGGER update_team_live_status_checked_at
    BEFORE UPDATE ON team_live_status
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- HELPER FUNCTIONS
-- =====================

-- Function to check if a player is in a "live window" (for cache TTL)
CREATE OR REPLACE FUNCTION is_player_live(p_player_id VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_team_id VARCHAR(100);
    v_is_live BOOLEAN;
    v_last_game_end TIMESTAMP;
BEGIN
    -- Get player's current team
    SELECT current_team_id INTO v_team_id
    FROM players
    WHERE id = p_player_id;

    IF v_team_id IS NULL THEN
        RETURN false;
    END IF;

    -- Check team live status
    SELECT is_live, last_game_end_time
    INTO v_is_live, v_last_game_end
    FROM team_live_status
    WHERE team_id = v_team_id;

    -- Player is "live" if team is currently playing or game ended within 3 hours
    IF v_is_live THEN
        RETURN true;
    ELSIF v_last_game_end IS NOT NULL AND v_last_game_end > NOW() - INTERVAL '3 hours' THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- COMMENTS
-- =====================

COMMENT ON TABLE nba_player_season_summary IS 'Precomputed season aggregates for NBA players. team_id=NULL means TOTAL across all teams.';
COMMENT ON TABLE nba_player_game_logs IS 'Individual game performance logs for NBA players';
COMMENT ON TABLE nba_player_splits IS 'Precomputed statistical splits (home/away, monthly, last N games)';
COMMENT ON TABLE nba_player_career_summary IS 'Career historical season-by-season summaries';
COMMENT ON TABLE team_live_status IS 'Tracks team live game status for cache TTL decisions';
