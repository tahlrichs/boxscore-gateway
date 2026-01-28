import { createClient } from '@supabase/supabase-js';
import { config } from '../config';

// Admin client with service role key for user management
export const supabaseAdmin = createClient(
  config.supabase.url,
  config.supabase.serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);
