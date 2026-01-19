/**
 * PostgreSQL connection pool
 * Provides database access for the gateway
 */

import { Pool, PoolClient } from 'pg';
import { logger } from '../utils/logger';

// Create connection pool
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

// Log pool errors
pool.on('error', (err: Error) => {
  logger.error('Unexpected error on idle database client', err);
});

// Test connection on startup
export async function testDatabaseConnection(): Promise<boolean> {
  try {
    const client = await pool.connect();
    await client.query('SELECT NOW()');
    client.release();
    logger.info('Database connection successful');
    return true;
  } catch (error) {
    logger.error('Database connection failed', error);
    return false;
  }
}

// Execute a query with automatic error handling
export async function query<T = any>(
  text: string,
  params?: any[]
): Promise<T[]> {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    logger.debug('Executed query', { text, duration, rows: result.rowCount });
    return result.rows;
  } catch (error) {
    logger.error('Database query error', { text, error });
    throw error;
  }
}

// Get a client for transactions
export async function getClient(): Promise<PoolClient> {
  return await pool.connect();
}

// Graceful shutdown
export async function closePool(): Promise<void> {
  await pool.end();
  logger.info('Database pool closed');
}
