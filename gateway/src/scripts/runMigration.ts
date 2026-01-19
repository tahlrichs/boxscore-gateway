#!/usr/bin/env ts-node
/**
 * Run Database Migration
 * Applies the player stats migration using Node.js pg client
 */

import { config } from 'dotenv';
import { readFileSync } from 'fs';
import { join } from 'path';
import { pool, closePool } from '../db/pool';
import { logger } from '../utils/logger';

config();

/**
 * Split SQL file into individual statements, respecting $$ function delimiters
 */
function splitSQLStatements(sql: string): string[] {
  const statements: string[] = [];
  let currentStatement = '';
  let inDollarQuote = false;
  let dollarTag = '';

  const lines = sql.split('\n');

  for (const line of lines) {
    // Skip comment-only lines
    if (line.trim().startsWith('--')) {
      continue;
    }

    // Check for dollar-quote delimiter
    const dollarMatch = line.match(/\$(\w*)\$/);
    if (dollarMatch) {
      if (!inDollarQuote) {
        // Starting dollar quote
        inDollarQuote = true;
        dollarTag = dollarMatch[0];
      } else if (dollarMatch[0] === dollarTag) {
        // Ending dollar quote
        inDollarQuote = false;
        dollarTag = '';
      }
    }

    currentStatement += line + '\n';

    // If we hit a semicolon and we're not in a dollar-quoted block, end the statement
    if (line.trim().endsWith(';') && !inDollarQuote) {
      statements.push(currentStatement);
      currentStatement = '';
    }
  }

  // Add any remaining statement
  if (currentStatement.trim().length > 0) {
    statements.push(currentStatement);
  }

  return statements;
}

async function runMigration() {
  try {
    logger.info('Starting database migration...');

    // First apply base schema
    const baseSchemPath = join(__dirname, '..', 'db', 'schema.sql');
    const baseSchemaSQL = readFileSync(baseSchemPath, 'utf-8');

    logger.info('Applying base schema: schema.sql');

    const baseStatements = splitSQLStatements(baseSchemaSQL);
    logger.info(`Executing ${baseStatements.length} base schema statements...`);

    for (let i = 0; i < baseStatements.length; i++) {
      const statement = baseStatements[i].trim();
      if (statement.length === 0) continue;

      try {
        await pool.query(statement);
        logger.debug(`Executed base schema statement ${i + 1}/${baseStatements.length}`);
      } catch (error) {
        // Ignore errors for statements that might already exist
        logger.debug(`Skipped statement ${i + 1} (may already exist)`, {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    logger.info('✓ Base schema applied');

    // Read player stats migration file
    const migrationPath = join(__dirname, '..', 'db', 'migrations', '001_player_stats_tables.sql');
    const migrationSQL = readFileSync(migrationPath, 'utf-8');

    logger.info('Applying migration: 001_player_stats_tables.sql');

    // Split migration into statements (respecting $$ delimiters for functions)
    const statements = splitSQLStatements(migrationSQL);

    logger.info(`Executing ${statements.length} SQL statements...`);

    // Execute each statement
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i].trim();
      if (statement.length === 0) continue;

      try {
        await pool.query(statement);
        logger.debug(`Executed statement ${i + 1}/${statements.length}`);
      } catch (error) {
        logger.error(`Failed at statement ${i + 1}`, {
          statement: statement.substring(0, 100) + '...',
          error: error instanceof Error ? error.message : String(error),
        });
        throw error;
      }
    }

    logger.info('✓ Migration applied successfully');
    console.log('✓ Migration applied successfully');

    await closePool();
    process.exit(0);
  } catch (error) {
    logger.error('Migration failed', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    console.error('✗ Migration failed:', error);
    if (error instanceof Error && error.stack) {
      console.error('Stack trace:', error.stack);
    }
    await closePool();
    process.exit(1);
  }
}

runMigration();
