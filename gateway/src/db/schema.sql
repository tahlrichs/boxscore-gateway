-- BoxScore Gateway Database Schema
-- This schema supports ID mapping for provider migration

-- =====================
-- EXTERNAL IDS TABLE
-- Maps internal canonical IDs to provider-specific IDs
-- =====================

CREATE TABLE IF NOT EXISTS external_ids (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,     -- 'team', 'player', 'game', 'league', 'venue'
    internal_id VARCHAR(100) NOT NULL,     -- Our canonical ID (e.g., 'nba_lal')
    provider VARCHAR(50) NOT NULL,         -- 'api_sports', 'sportradar', 'sportsdataio'
    provider_id VARCHAR(100) NOT NULL,     -- Provider's ID for this entity
    metadata JSONB,                         -- Additional provider-specific data
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Ensure unique mapping per entity/provider
    UNIQUE(entity_type, internal_id, provider),
    -- Index for reverse lookups
    UNIQUE(entity_type, provider, provider_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_external_ids_internal 
    ON external_ids(entity_type, internal_id);
CREATE INDEX IF NOT EXISTS idx_external_ids_provider 
    ON external_ids(entity_type, provider, provider_id);

-- =====================
-- LEAGUE SEASONS TABLE
-- Defines season boundaries for each league
-- =====================

CREATE TABLE IF NOT EXISTS league_seasons (
    id VARCHAR(50) PRIMARY KEY,              -- e.g., 'nba_2025-26'
    league_id VARCHAR(50) NOT NULL,          -- e.g., 'nba'
    season_label VARCHAR(20) NOT NULL,       -- e.g., '2025-26'
    start_date DATE NOT NULL,                -- Regular season start
    end_date DATE NOT NULL,                  -- Regular season end
    preseason_start DATE,                    -- Preseason start (optional)
    postseason_end DATE,                     -- Postseason end (optional)
    status VARCHAR(20) DEFAULT 'offseason',  -- preseason/regular/postseason/offseason
    schedule_source VARCHAR(50),             -- 'espn', 'manual', etc.
    last_schedule_sync_at TIMESTAMP,
    last_standings_sync_at TIMESTAMP,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_league_seasons_league ON league_seasons(league_id);
CREATE INDEX IF NOT EXISTS idx_league_seasons_dates ON league_seasons(start_date, end_date);

-- =====================
-- TEAMS TABLE
-- Canonical team data
-- =====================

CREATE TABLE IF NOT EXISTS teams (
    id VARCHAR(100) PRIMARY KEY,           -- Canonical ID (e.g., 'nba_lal')
    league_id VARCHAR(50) NOT NULL,        -- League identifier
    name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    abbreviation VARCHAR(10),
    primary_color VARCHAR(10),             -- Hex color
    logo_url TEXT,
    conference VARCHAR(100),
    division VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_teams_league ON teams(league_id);

-- =====================
-- PLAYERS TABLE  
-- Canonical player data
-- =====================

CREATE TABLE IF NOT EXISTS players (
    id VARCHAR(100) PRIMARY KEY,           -- Canonical ID (e.g., 'player_12345')
    team_id VARCHAR(100) REFERENCES teams(id),
    name VARCHAR(200) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    jersey VARCHAR(10),
    position VARCHAR(50),
    height VARCHAR(20),
    weight VARCHAR(20),
    birthdate DATE,
    college VARCHAR(200),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_id);

-- =====================
-- GAMES TABLE
-- Canonical game records
-- =====================

CREATE TABLE IF NOT EXISTS games (
    id VARCHAR(100) PRIMARY KEY,           -- Canonical ID (e.g., 'nba_401810365')
    league_id VARCHAR(50) NOT NULL,
    season_id VARCHAR(50) REFERENCES league_seasons(id),  -- FK to league_seasons
    game_date DATE NOT NULL,               -- Original date field (kept for compatibility)
    scoreboard_date DATE NOT NULL,         -- Canonical grouping date (US/Eastern for NBA)
    start_time TIMESTAMP,
    start_time_utc TIMESTAMP,              -- UTC timestamp for accurate sorting
    home_team_id VARCHAR(100) REFERENCES teams(id),
    away_team_id VARCHAR(100) REFERENCES teams(id),
    home_score INTEGER,
    away_score INTEGER,
    status VARCHAR(50),                     -- 'scheduled', 'live', 'final'
    period VARCHAR(20),
    clock VARCHAR(20),
    venue_id VARCHAR(100),
    external_ids JSONB DEFAULT '{}',       -- Provider IDs: { "espn": "401810365", "sportradar": "..." }
    last_refreshed_at TIMESTAMP,           -- When game data was last fetched from provider
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_games_date ON games(game_date);
CREATE INDEX IF NOT EXISTS idx_games_scoreboard_date ON games(scoreboard_date);
CREATE INDEX IF NOT EXISTS idx_games_league_date ON games(league_id, game_date);
CREATE INDEX IF NOT EXISTS idx_games_league_scoreboard_date ON games(league_id, scoreboard_date);
CREATE INDEX IF NOT EXISTS idx_games_season ON games(season_id);
CREATE INDEX IF NOT EXISTS idx_games_status ON games(status);

-- =====================
-- GAME DATES TABLE
-- Derived index of dates that have games (materialized from games table)
-- =====================

CREATE TABLE IF NOT EXISTS game_dates (
    league_id VARCHAR(50) NOT NULL,
    season_id VARCHAR(50) REFERENCES league_seasons(id),
    scoreboard_date DATE NOT NULL,
    game_count INTEGER DEFAULT 0,
    first_game_time_utc TIMESTAMP,
    last_game_time_utc TIMESTAMP,
    has_live_games BOOLEAN DEFAULT false,
    all_games_final BOOLEAN DEFAULT false,
    last_refreshed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (league_id, scoreboard_date)
);

CREATE INDEX IF NOT EXISTS idx_game_dates_season ON game_dates(season_id);
CREATE INDEX IF NOT EXISTS idx_game_dates_league_season ON game_dates(league_id, season_id);

-- =====================
-- PROVIDER SYNC LOG
-- Track provider data synchronization
-- =====================

CREATE TABLE IF NOT EXISTS provider_sync_log (
    id SERIAL PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    league_id VARCHAR(50),
    sync_date DATE,
    records_processed INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    errors JSONB,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'running'   -- 'running', 'completed', 'failed'
);

CREATE INDEX IF NOT EXISTS idx_sync_log_provider ON provider_sync_log(provider, entity_type);

-- =====================
-- FUNCTIONS
-- =====================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to tables
DROP TRIGGER IF EXISTS update_external_ids_updated_at ON external_ids;
CREATE TRIGGER update_external_ids_updated_at
    BEFORE UPDATE ON external_ids
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_teams_updated_at ON teams;
CREATE TRIGGER update_teams_updated_at
    BEFORE UPDATE ON teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_players_updated_at ON players;
CREATE TRIGGER update_players_updated_at
    BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_games_updated_at ON games;
CREATE TRIGGER update_games_updated_at
    BEFORE UPDATE ON games
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_league_seasons_updated_at ON league_seasons;
CREATE TRIGGER update_league_seasons_updated_at
    BEFORE UPDATE ON league_seasons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_game_dates_updated_at ON game_dates;
CREATE TRIGGER update_game_dates_updated_at
    BEFORE UPDATE ON game_dates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- VIEWS
-- =====================

-- View for easy ID lookups
CREATE OR REPLACE VIEW v_id_mappings AS
SELECT 
    e.entity_type,
    e.internal_id,
    e.provider,
    e.provider_id,
    CASE e.entity_type
        WHEN 'team' THEN t.name
        WHEN 'player' THEN p.name
        ELSE NULL
    END as entity_name
FROM external_ids e
LEFT JOIN teams t ON e.entity_type = 'team' AND e.internal_id = t.id
LEFT JOIN players p ON e.entity_type = 'player' AND e.internal_id = p.id;

-- =====================
-- GAME DATES MATERIALIZATION
-- Function to rebuild game_dates from games table
-- =====================

CREATE OR REPLACE FUNCTION materialize_game_dates(p_season_id VARCHAR DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- Upsert game_dates from games table
    INSERT INTO game_dates (
        league_id,
        season_id,
        scoreboard_date,
        game_count,
        first_game_time_utc,
        last_game_time_utc,
        has_live_games,
        all_games_final,
        last_refreshed_at,
        created_at,
        updated_at
    )
    SELECT 
        g.league_id,
        g.season_id,
        g.scoreboard_date,
        COUNT(*) as game_count,
        MIN(g.start_time_utc) as first_game_time_utc,
        MAX(g.start_time_utc) as last_game_time_utc,
        BOOL_OR(g.status = 'live') as has_live_games,
        BOOL_AND(g.status = 'final') as all_games_final,
        MAX(g.last_refreshed_at) as last_refreshed_at,
        NOW() as created_at,
        NOW() as updated_at
    FROM games g
    WHERE (p_season_id IS NULL OR g.season_id = p_season_id)
    GROUP BY g.league_id, g.season_id, g.scoreboard_date
    ON CONFLICT (league_id, scoreboard_date) 
    DO UPDATE SET 
        season_id = EXCLUDED.season_id,
        game_count = EXCLUDED.game_count,
        first_game_time_utc = EXCLUDED.first_game_time_utc,
        last_game_time_utc = EXCLUDED.last_game_time_utc,
        has_live_games = EXCLUDED.has_live_games,
        all_games_final = EXCLUDED.all_games_final,
        last_refreshed_at = EXCLUDED.last_refreshed_at,
        updated_at = NOW();
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- SEED DATA
-- Initial league season data
-- =====================

-- NBA 2025-26 Season
INSERT INTO league_seasons (
    id, 
    league_id, 
    season_label, 
    start_date, 
    end_date, 
    preseason_start, 
    postseason_end, 
    status, 
    schedule_source,
    metadata
)
VALUES (
    'nba_2025-26',
    'nba',
    '2025-26',
    '2025-10-22',  -- Regular season start
    '2026-04-13',  -- Regular season end
    '2025-10-04',  -- Preseason start
    '2026-06-22',  -- Finals end (approx)
    'regular',     -- Current status
    'espn',
    '{"timezone": "US/Eastern", "notes": "Scoreboard dates use US/Eastern timezone"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    preseason_start = EXCLUDED.preseason_start,
    postseason_end = EXCLUDED.postseason_end,
    status = EXCLUDED.status,
    metadata = EXCLUDED.metadata;

-- NFL 2025 Season
INSERT INTO league_seasons (
    id, 
    league_id, 
    season_label, 
    start_date, 
    end_date, 
    preseason_start, 
    postseason_end, 
    status, 
    schedule_source,
    metadata
)
VALUES (
    'nfl_2025',
    'nfl',
    '2025',
    '2025-09-04',  -- Regular season start (Thursday opener)
    '2026-01-04',  -- Regular season end (Week 18)
    '2025-08-01',  -- Preseason start
    '2026-02-08',  -- Super Bowl LX
    'regular',     -- Current status
    'espn',
    '{"timezone": "US/Eastern", "notes": "NFL games mostly on Sundays, with Thursday/Monday games"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    preseason_start = EXCLUDED.preseason_start,
    postseason_end = EXCLUDED.postseason_end,
    status = EXCLUDED.status,
    metadata = EXCLUDED.metadata;

-- NCAAF 2025 Season
INSERT INTO league_seasons (
    id, 
    league_id, 
    season_label, 
    start_date, 
    end_date, 
    preseason_start, 
    postseason_end, 
    status, 
    schedule_source,
    metadata
)
VALUES (
    'ncaaf_2025',
    'ncaaf',
    '2025',
    '2025-08-23',  -- Regular season start (Week 0)
    '2025-12-07',  -- Regular season end (Championship Week)
    '2025-08-23',  -- Same as regular season start
    '2026-01-20',  -- National Championship
    'regular',     -- Current status
    'espn',
    '{"timezone": "US/Eastern", "notes": "College football games mostly on Saturdays"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    preseason_start = EXCLUDED.preseason_start,
    postseason_end = EXCLUDED.postseason_end,
    status = EXCLUDED.status,
    metadata = EXCLUDED.metadata;

-- NCAAM 2025-26 Season
INSERT INTO league_seasons (
    id, 
    league_id, 
    season_label, 
    start_date, 
    end_date, 
    preseason_start, 
    postseason_end, 
    status, 
    schedule_source,
    metadata
)
VALUES (
    'ncaam_2025-26',
    'ncaam',
    '2025-26',
    '2025-11-04',  -- Regular season start
    '2026-03-08',  -- Regular season end (Selection Sunday)
    '2025-11-04',  -- Same as regular season start
    '2026-04-06',  -- National Championship (Final Four)
    'regular',     -- Current status
    'espn',
    '{"timezone": "US/Eastern", "notes": "College basketball season, March Madness starts mid-March"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    preseason_start = EXCLUDED.preseason_start,
    postseason_end = EXCLUDED.postseason_end,
    status = EXCLUDED.status,
    metadata = EXCLUDED.metadata;
