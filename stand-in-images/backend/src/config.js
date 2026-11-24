// Release 1.1: configuration loading is centralised here. Every setting is
// read once at start-up and validated. A missing required setting stops the
// process with a message naming it, instead of failing later at runtime.

function required(name, description) {
  const value = process.env[name];
  if (value === undefined || value === '') {
    console.error(`[config] FATAL: required environment variable ${name} is not set (${description})`);
    process.exit(1);
  }
  return value;
}

function positiveInt(name, description) {
  const raw = required(name, description);
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1) {
    console.error(`[config] FATAL: environment variable ${name}="${raw}" is not valid (${description})`);
    process.exit(1);
  }
  return n;
}

const config = {
  appPort: Number(process.env.APP_PORT) || 8080,
  corsOrigin: process.env.CORS_ORIGIN || '*',
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || 'devdb',
    user: process.env.DB_USER || 'devuser',
    password: process.env.DB_PASSWORD || 'devpass',
    // New in 1.1: the connection pool size has no default.
    max: positiveInt('DB_POOL_MAX', 'maximum number of database connections, a positive integer such as "10"'),
  },
};

console.log(`[config] loaded: db ${config.db.host}:${config.db.port}/${config.db.database}, pool max ${config.db.max}`);

module.exports = config;
