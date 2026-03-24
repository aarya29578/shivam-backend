const express = require('express');
const router = express.Router();
const User = require('../models/User');

// POST /api/add-user — Add a new user
router.post('/add-user', async (req, res) => {
  try {
    const { name, email } = req.body;

    if (!name || !email) {
      return res.status(400).json({ error: 'Name and email are required.' });
    }

    const user = new User({ name, email });
    await user.save();

    res.status(201).json({ message: 'User added successfully.', user });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ error: 'Email already exists.' });
    }
    res.status(500).json({ error: err.message });
  }
});

// GET /api/users — Fetch all users
router.get('/users', async (req, res) => {
  try {
    const users = await User.find().sort({ createdAt: -1 });
    res.status(200).json({ count: users.length, users });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
