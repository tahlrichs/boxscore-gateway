---
module: Gateway Infrastructure
date: 2026-01-27
problem_type: integration_issue
component: railway_deployment
symptoms:
  - "Redis Client Error: Connection timeout"
  - "Redis not available, running without cache"
  - "cache.connected: false in health endpoint"
  - "Redis deployments stuck at Creating containers"
root_cause: stale_redis_service
severity: high
tags: [railway, redis, private-networking, ipv6, deployment]
---

# Railway Redis Private Networking Connection Timeout

## Symptom

After deploying BoxScore gateway to Railway with Redis, the gateway repeatedly failed to connect to Redis via private networking:

```
Redis Client Error: Connection timeout
Error: Connection timeout
    at Socket.<anonymous> (/app/node_modules/@redis/client/dist/lib/client/socket.js:177:124)
Redis not available, running without cache
```

Health endpoint showed:
```json
{
  "status": "unhealthy",
  "cache": { "connected": false }
}
```

## Environment

- **Platform**: Railway (production deployment)
- **Redis URL**: `redis://default:***@redis.railway.internal:6379`
- **Gateway**: Node.js/Express with `redis` npm package
- **Private Networking**: Both services had IPv4 & IPv6 enabled

## Investigation Steps

### 1. Verified Configuration (Not the issue)
- REDIS_URL correctly set in gateway Variables
- Private networking enabled on both gateway and Redis services
- Internal hostname `redis.railway.internal` resolved correctly

### 2. Tried IPv6 Fix (Partial improvement)
Added IPv6 socket family to Redis client config:
```typescript
redisClient = createClient({
  url: config.redisUrl,
  socket: {
    connectTimeout: 5000,
    reconnectStrategy: false,
    family: 6, // Use IPv6 for Railway's private networking
  },
});
```
**Result**: Still timed out

### 3. Tried Shorter Hostname (No change)
Changed `redis.railway.internal` to just `redis` (Railway's suggested alias)
**Result**: Still timed out

### 4. Checked Redis Service Health (Found the issue)
- Redis logs showed **nothing** (empty)
- Railway UI showed "Could not establish SSH connection to application"
- New Redis deployments got **stuck at "Creating containers"** for 3+ minutes

## Root Cause

The Redis service was in a **corrupted/stale state**:
- No logs being generated
- Unable to accept connections
- New deployments failing to create containers
- Railway's internal database connection check failing

This was NOT a networking or configuration issue - the Redis service itself was broken.

## Solution

**Delete and recreate the Redis service:**

1. Go to Redis service → Settings → Danger → **Delete Service**
2. In project, click "+ Create" → "Database" → "Redis"
3. Wait for new Redis to show **"Online"** (not "Deploying")
4. Update gateway's `REDIS_URL` with new Redis connection string
5. Redeploy gateway

After fresh Redis creation:
```json
{
  "status": "healthy",
  "cache": { "connected": true }
}
```

## Code Changes Required

For Railway private networking, the Redis client needs IPv6 support:

```typescript
// gateway/src/cache/redis.ts
redisClient = createClient({
  url: config.redisUrl,
  socket: {
    connectTimeout: 5000,
    reconnectStrategy: false,
    family: 6, // Required for Railway's private networking (IPv6)
  },
});
```

## Prevention

1. **Check Redis logs first** when connection issues occur - empty logs indicate a broken service
2. **Monitor Railway service health** - "Could not establish SSH connection" is a red flag
3. **Don't waste time on config changes** if the underlying service is unhealthy
4. **Railway services can become stale** - recreating is often faster than debugging

## Diagnostic Checklist

When Redis won't connect on Railway:

- [ ] Check gateway's REDIS_URL variable matches Redis internal URL
- [ ] Check private networking enabled on **both** services
- [ ] Check Redis deployment logs (if empty = bad sign)
- [ ] Check if new Redis deployments complete or get stuck
- [ ] Try Railway's Database tab - does it show "Could not establish SSH connection"?
- [ ] If multiple indicators of unhealthy Redis → delete and recreate

## Related

- Railway Private Networking Docs: https://docs.railway.app/reference/private-networking
- Redis npm package: https://github.com/redis/node-redis
