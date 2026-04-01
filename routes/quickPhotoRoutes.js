const express = require('express');
const router  = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const ctrl           = require('../controllers/quickPhotoController');

// POST /api/upload/quick-photo — vendor uploads one photo (auth required)
router.post(
  '/quick-photo',
  authMiddleware,
  ctrl.uploadMiddleware,
  ctrl.uploadQuickPhoto,
);

// GET /api/upload/quick-photos?schoolCode=X&className=Y (auth required)
router.get('/quick-photos', authMiddleware, ctrl.getQuickPhotos);

module.exports = router;
