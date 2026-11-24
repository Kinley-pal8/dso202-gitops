const config = require('./config');
const express = require('express');
const cors = require('cors');
const { waitForDatabase, pool } = require('./db');
const tasksRouter = require('./routes/tasks');

const APP_PORT = config.appPort;
const CORS_ORIGIN = config.corsOrigin;

const app = express();
app.use(cors({ origin: CORS_ORIGIN }));
app.use(express.json());

app.get('/api/status', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected' });
  } catch {
    res.status(503).json({ status: 'degraded', db: 'unreachable' });
  }
});

app.use('/api/tasks', tasksRouter);

waitForDatabase().then(() => {
  app.listen(APP_PORT, () => console.log(`[server] listening on :${APP_PORT}`));
});
