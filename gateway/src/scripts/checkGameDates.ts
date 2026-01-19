import { query } from '../db/pool';
import { logger } from '../utils/logger';

async function checkGameDates() {
  const result = await query(
    'SELECT DISTINCT game_date FROM games WHERE league_id = $1 ORDER BY game_date DESC LIMIT 10',
    ['nba']
  );

  console.log('Recent NBA game dates:');
  result.forEach(r => console.log(r.game_date));

  process.exit(0);
}

checkGameDates().catch(err => {
  console.error(err);
  process.exit(1);
});
