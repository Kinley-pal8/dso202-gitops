const { Pool } = require('pg');

const config = require('./config');

const pool = new Pool(config.db);

const RETRY_DELAY_MS = 2000;

// Unit I scope has no readiness probe, so the process itself must not
// exit when the database Pod isn't up yet -- it waits it out instead.
async function waitForDatabase() {
  for (;;) {
    try {
      await pool.query('SELECT 1');
      console.log('[db] connected');
      return;
    } catch (err) {
      console.log(`[db] not reachable yet (${err.code || err.message}), retrying in ${RETRY_DELAY_MS}ms`);
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
    }
  }
}

module.exports = { pool, waitForDatabase };
