/**
 * /api/projects  — shared with EP Admin Portal (same MongoDB projects collection)
 *
 * Flutter vendor app calls these routes to create orders that are immediately
 * visible in the EP web admin Projects kanban board.
 */
const express  = require('express');
const router   = express.Router();
const path     = require('path');
const fs       = require('fs');
const multer   = require('multer');
const Project  = require('../models/Project');
const Order    = require('../models/Order');
const Client   = require('../models/Client');

// ── Multer for project file attachments (reuses order-files storage dir) ──
const orderFilesDir = path.join(__dirname, '..', 'uploads', 'order-files');
if (!fs.existsSync(orderFilesDir)) fs.mkdirSync(orderFilesDir, { recursive: true });

const _storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, orderFilesDir),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e6)}`;
    cb(null, `${unique}${path.extname(file.originalname)}`);
  },
});
const _upload = multer({ storage: _storage, limits: { fileSize: 50 * 1024 * 1024 } });

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/projects
// Creates a Project (shared EP collection) and a vendor Order in parallel.
// Returns the Project's _id so the client can attach files to it.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res) => {
  try {
    console.log('[POST /api/projects] body:', JSON.stringify(req.body));
    const {
      title, name,           // accept both; 'name' wins if provided
      schoolName, client,    // accept both
      clientId,
      schoolCode: schoolCodeRaw,
      productId,
      productType,
      productName,
      productImage,
      pricing,
      variableFields,
      columnMappings,
      deliveryDate,
      description,
      stage,
      vendorId,
    } = req.body;

    const projectName  = (name || title || 'Untitled Order').toString().trim();
    const clientName   = (client || schoolName || '').toString().trim();

    if (!projectName) {
      return res.status(400).json({ error: 'name (or title) is required.' });
    }

    // Resolve schoolCode: prefer explicit value, fall back to DB lookup
    let schoolCode = schoolCodeRaw ? schoolCodeRaw.toString().trim().toUpperCase() : undefined;
    if (!schoolCode && clientId) {
      const c = await Client.findById(clientId).select('schoolCode').lean();
      if (c?.schoolCode) schoolCode = c.schoolCode;
    }

    const projectData = {
      name:           projectName,
      client:         clientName,
      description:    description || '',
      status:         'draft',
      stage:          'draft',
      productName:    productName  || '',
      productImage:   productImage || '',
      pricing:        pricing      || {},
      variableFields: Array.isArray(variableFields) ? variableFields : [],
      columnMappings: columnMappings || {},
      createdBy:      'vendor',
      amount:         0,
      pages:          1,
      workflowType:   'direct_print',
      ...(clientId && { clientId }),
      ...(deliveryDate && { dueDate: deliveryDate }),
    };

    // Save to shared `projects` collection (EP web admin reads this)
    const project = await Project.create(projectData);

    console.log('[POST /api/projects] Created project:', {
      id:     project._id,
      name:   project.name,
      client: project.client,
      status: project.status,
    });

    // Also create an Order so vendor app order board is populated (fire-and-forget)
    Order.create({
      title:          projectName,
      schoolName:     clientName,
      stage:          'Draft',
      progress:       0,
      totalCards:     0,
      completedCards: 0,
      vendorId:       vendorId || 'unknown',
      description:    description || '',
      productName:    productName  || '',
      productImage:   productImage || '',
      pricing:        pricing      || {},
      variableFields: Array.isArray(variableFields) ? variableFields : [],
      columnMappings: columnMappings || {},
      ...(clientId    && { clientId }),
      ...(schoolCode  && { schoolCode }),
      ...(productId   && { productId }),
      ...(productType && { productType }),
      ...(deliveryDate && { deliveryDate: new Date(deliveryDate) }),
    }).then((order) => {
      // Link the vendor order back to the project
      Project.findByIdAndUpdate(project._id, { vendorOrderId: order._id.toString() }).exec();
    }).catch((e) => {
      console.warn('[POST /api/projects] Order mirror failed (non-fatal):', e.message);
    });

    return res.status(201).json({
      id:         project._id,
      name:       project.name,
      client:     project.client,
      status:     project.status,
      stage:      project.stage,
    });
  } catch (err) {
    console.error('[POST /api/projects] ERROR:', err.message, err.stack);
    return res.status(500).json({ error: err.message || 'Failed to create project.' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/projects
// Returns all projects, optionally filtered by ?status=draft
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const filter = {};
    if (req.query.status) filter.status = req.query.status;
    const projects = await Project.find(filter).sort({ createdAt: -1 }).lean();
    return res.json({ success: true, data: projects });
  } catch (err) {
    console.error('[GET /api/projects]', err);
    return res.status(500).json({ error: 'Failed to fetch projects.' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/projects/:id/files
// Attaches uploaded files to an existing project.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/:id/files', _upload.array('files', 20), async (req, res) => {
  try {
    const project = await Project.findById(req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found.' });

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files received.' });
    }

    const serverBase = (process.env.SERVER_BASE_URL || `http://localhost:${process.env.PORT || 5001}`).replace(/\/$/, '');
    const newEntries = req.files.map((f) => ({
      originalName: f.originalname,
      filename:     f.filename,
      path:         `${serverBase}/uploads/order-files/${f.filename}`,
      mimeType:     f.mimetype,
      size:         f.size,
    }));

    project.files.push(...newEntries);
    await project.save();

    console.log('[POST /api/projects/:id/files] Attached', newEntries.length, 'file(s) to project', req.params.id);

    return res.status(201).json({
      projectId: project._id,
      uploaded:  newEntries.length,
      files:     newEntries,
    });
  } catch (err) {
    console.error('[POST /api/projects/:id/files]', err);
    return res.status(500).json({ error: 'Failed to upload files.' });
  }
});

module.exports = router;
