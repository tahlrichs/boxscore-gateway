import { Router, Request, Response } from 'express';
import * as fs from 'fs';
import * as path from 'path';

const dataPath = path.join(__dirname, '..', 'data', 'teamColors.json');

// Fail fast if JSON file is missing at startup
if (!fs.existsSync(dataPath)) {
  throw new Error(`teamColors.json not found at ${dataPath}`);
}

// Read once at startup, serve from memory
const teamColors = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));

export const teamColorsRouter = Router();

teamColorsRouter.get('/', (_req: Request, res: Response) => {
  res.set('Cache-Control', 'public, max-age=86400');
  res.json({ data: teamColors });
});
