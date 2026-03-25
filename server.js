const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const userRoutes      = require('./routes/userRoutes');
const vendorRoutes    = require('./routes/vendorRoutes');
const principalRoutes = require('./routes/principalRoutes');

const app = express();

// Trust Nginx reverse proxy (fixes IP, protocol headers)
app.set('trust proxy', true);

// Middleware
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logger
app.use((req, res, next) => {
  const ip = req.ip || req.socket.remoteAddress;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} — IP: ${ip}`);
  next();
});

// Routes
app.use('/api', userRoutes);
app.use('/api/vendor', vendorRoutes);
app.use('/api/principal', principalRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'Edumid API is running.' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found.' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error.' });
});

// Connect to MongoDB and start server
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error('FATAL: MONGO_URI is not defined. Create a .env file in the backend root with MONGO_URI=<your_connection_string>');
  process.exit(1);
}

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('MongoDB Connected');
    app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err.message);
    process.exit(1);
  });
