-- Seed all 30 NBA teams (BOX-48)
-- Team IDs match the format produced by ESPNAdapter.transformCompetitorToTeam(): nba_{espn_team_id}
-- Required to satisfy FK constraints on games.home_team_id / games.away_team_id

INSERT INTO teams (id, league_id, name, abbreviation) VALUES
  ('nba_1',  'nba', 'Atlanta Hawks',            'ATL'),
  ('nba_2',  'nba', 'Boston Celtics',           'BOS'),
  ('nba_3',  'nba', 'New Orleans Pelicans',     'NO'),
  ('nba_4',  'nba', 'Chicago Bulls',            'CHI'),
  ('nba_5',  'nba', 'Cleveland Cavaliers',      'CLE'),
  ('nba_6',  'nba', 'Dallas Mavericks',         'DAL'),
  ('nba_7',  'nba', 'Denver Nuggets',           'DEN'),
  ('nba_8',  'nba', 'Detroit Pistons',          'DET'),
  ('nba_9',  'nba', 'Golden State Warriors',    'GS'),
  ('nba_10', 'nba', 'Houston Rockets',          'HOU'),
  ('nba_11', 'nba', 'Indiana Pacers',           'IND'),
  ('nba_12', 'nba', 'LA Clippers',              'LAC'),
  ('nba_13', 'nba', 'Los Angeles Lakers',       'LAL'),
  ('nba_14', 'nba', 'Miami Heat',               'MIA'),
  ('nba_15', 'nba', 'Milwaukee Bucks',          'MIL'),
  ('nba_16', 'nba', 'Minnesota Timberwolves',   'MIN'),
  ('nba_17', 'nba', 'Brooklyn Nets',            'BKN'),
  ('nba_18', 'nba', 'New York Knicks',          'NY'),
  ('nba_19', 'nba', 'Orlando Magic',            'ORL'),
  ('nba_20', 'nba', 'Philadelphia 76ers',       'PHI'),
  ('nba_21', 'nba', 'Phoenix Suns',             'PHX'),
  ('nba_22', 'nba', 'Portland Trail Blazers',   'POR'),
  ('nba_23', 'nba', 'Sacramento Kings',         'SAC'),
  ('nba_24', 'nba', 'San Antonio Spurs',        'SA'),
  ('nba_25', 'nba', 'Oklahoma City Thunder',    'OKC'),
  ('nba_26', 'nba', 'Toronto Raptors',          'TOR'),
  ('nba_27', 'nba', 'Utah Jazz',                'UTA'),
  ('nba_28', 'nba', 'Washington Wizards',       'WAS'),
  ('nba_29', 'nba', 'Memphis Grizzlies',        'MEM'),
  ('nba_30', 'nba', 'Charlotte Hornets',        'CHA')
ON CONFLICT (id) DO NOTHING;
