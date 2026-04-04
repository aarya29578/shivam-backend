const Client       = require('../models/Client');
const Order        = require('../models/Order');
const User         = require('../models/User');
const SchoolClass  = require('../models/SchoolClass');
const SchoolMember = require('../models/SchoolMember');
const path         = require('path');
const fs           = require('fs');
const multer       = require('multer');
const XLSX         = require('xlsx');

// ── Order-file upload (multer) ──────────────────────────────────────
const orderFilesDir = path.join(__dirname, '..', 'uploads', 'order-files');
if (!fs.existsSync(orderFilesDir)) fs.mkdirSync(orderFilesDir, { recursive: true });

const _orderFileStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, orderFilesDir),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e6)}`;
    const ext    = path.extname(file.originalname);
    cb(null, `${unique}${ext}`);
  },
});

const _orderFileUpload = multer({
  storage: _orderFileStorage,
  limits:  { fileSize: 50 * 1024 * 1024 }, // 50 MB per file
  fileFilter: (_req, file, cb) => {
    const allowed = [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'application/pdf',
      'application/postscript',           // .ai / .eps
      'image/vnd.adobe.photoshop',        // .psd
      'image/svg+xml',                    // .svg
      'application/msword',               // .doc
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // .docx
      'application/vnd.ms-excel',                                               // .xls
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',      // .xlsx
    ];
    // also allow by extension for CDR and other design files
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExts = ['.cdr', '.ai', '.psd', '.eps', '.svg'];
    if (allowed.includes(file.mimetype) || allowedExts.includes(ext)) {
      return cb(null, true);
    }
    cb(new Error(`File type not allowed: ${file.mimetype}`));
  },
});

/** Middleware - attach to route before uploadOrderFiles */
exports.uploadOrderFilesMiddleware = _orderFileUpload.array('files', 20);

function normalizeVendorCode(value) {
  return (value || '').toString().trim().toUpperCase();
}

function normalizeSchoolCode(value) {
  return (value || '').toString().trim().toUpperCase();
}

/**
 * GET /api/vendor/dashboard
 *
 * Query params:
 *   vendorId  (required) – identifies which vendor's data to return
 *
 * Response:
 * {
 *   totalClients:   number,
 *   activeOrders:   number,
 *   cardsToday:     number,
 *   activeProjects: [{ schoolName, stage, progress }]
 * }
 */
/**
 * GET /api/vendor/orders
 *
 * Query params:
 *   vendorId  (required)
 *
 * Response:
 * {
 *   Draft:       [{ id, title, schoolName, progress, stage }],
 *   "Data Upload": [...],
 *   ...
 * }
 */
/**
 * POST /api/vendor/clients
 *
 * Body: { schoolName, address?, city?, contactName?, phone?, email?, vendorId }
 */
exports.createClient = async (req, res) => {
  try {
    const {
      schoolName,
      schoolCode,
      address,
      city,
      contactName,
      phone,
      email,
      vendorId,
    } = req.body || {};
    if (!schoolName || !vendorId) {
      return res.status(400).json({ error: 'schoolName and vendorId are required.' });
    }
    const safeSchoolCode = normalizeSchoolCode(schoolCode);

    if (safeSchoolCode) {
      const existingByCode = await Client.findOne({
        vendorId,
        schoolCode: safeSchoolCode,
      }).lean();
      if (existingByCode) {
        return res.status(409).json({
          error: 'This school code is already linked to your account.',
        });
      }
    }

    const client = await Client.create({
      schoolName,
      vendorId,
      ...(safeSchoolCode && { schoolCode: safeSchoolCode }),
      ...(address     && { address }),
      ...(city        && { city }),
      ...(contactName && { contactName }),
      ...(phone       && { phone }),
      ...(email       && { email }),
    });
    return res.status(201).json({
      id:          client._id,
      schoolName:  client.schoolName,
      schoolCode:  client.schoolCode || '',
      city:        client.city        || '',
      contactName: client.contactName || '',
      phone:       client.phone       || '',
      email:       client.email       || '',
      address:     client.address     || '',
    });
  } catch (err) {
    console.error('[createClient]', err);
    return res.status(500).json({ error: err.message || 'Failed to create client.' });
  }
};

exports.deleteClient = async (req, res) => {
  try {
    const deleted = await Client.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Client not found.' });
    await Order.deleteMany({ clientId: deleted._id });
    return res.json({ message: 'Client deleted.' });
  } catch (err) {
    console.error('[deleteClient]', err);
    return res.status(500).json({ error: 'Failed to delete client.' });
  }
};

/**
 * PATCH /api/vendor/clients/:id
 *
 * Updates editable fields on a client (schoolCode, contactName, phone, address, city, email).
 */
exports.updateClient = async (req, res) => {
  try {
    const { schoolCode, contactName, phone, address, city, email } = req.body || {};
    const patch = {};
    if (schoolCode  !== undefined) patch.schoolCode  = normalizeSchoolCode(schoolCode);
    if (contactName !== undefined) patch.contactName = (contactName || '').toString().trim();
    if (phone       !== undefined) patch.phone       = (phone       || '').toString().trim();
    if (address     !== undefined) patch.address     = (address     || '').toString().trim();
    if (city        !== undefined) patch.city        = (city        || '').toString().trim();
    if (email       !== undefined) patch.email       = (email       || '').toString().trim().toLowerCase();

    const updated = await Client.findByIdAndUpdate(
      req.params.id,
      { $set: patch },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ error: 'Client not found.' });
    console.log(`[updateClient] id=${req.params.id} patch=${JSON.stringify(patch)}`);
    return res.json({
      id:          updated._id,
      schoolName:  updated.schoolName,
      schoolCode:  updated.schoolCode || '',
      city:        updated.city        || '',
      contactName: updated.contactName || '',
      phone:       updated.phone       || '',
      email:       updated.email       || '',
      address:     updated.address     || '',
    });
  } catch (err) {
    console.error('[updateClient]', err);
    return res.status(500).json({ error: 'Failed to update client.' });
  }
};

exports.getVendorClients = async (req, res) => {
  try {
    const { vendorId } = req.query;
    if (!vendorId) {
      return res.status(400).json({ error: 'vendorId query parameter is required.' });
    }
    const clients = await Client.find({ vendorId })
      .sort({ createdAt: -1 })
      .lean();
    return res.json(
      clients.map(c => ({
        id:          c._id,
        schoolName:  c.schoolName,
        schoolCode:  c.schoolCode || '',
        city:        c.city        || '',
        contactName: c.contactName || '',
        phone:       c.phone       || '',
        email:       c.email       || '',
        address:     c.address     || '',
      }))
    );
  } catch (err) {
    console.error('[getVendorClients]', err);
    return res.status(500).json({ error: 'Failed to load clients.' });
  }
};

exports.getVendorOrders = async (req, res) => {
  try {
    const { vendorId } = req.query;

    if (!vendorId) {
      return res.status(400).json({ error: 'vendorId query parameter is required.' });
    }

    const orders = await Order.find({ vendorId }).lean();

    // Build an object with every stage pre-initialised as an empty array
    const grouped = STAGES.reduce((acc, stage) => {
      acc[stage] = [];
      return acc;
    }, {});

    for (const order of orders) {
      const bucket = grouped[order.stage];
      if (bucket) {
        bucket.push({
          id:         order._id,
          title:      order.title,
          schoolName: order.schoolName,
          progress:   order.progress,
          stage:      order.stage,
        });
      }
    }

    return res.json(grouped);
  } catch (err) {
    console.error('[getVendorOrders]', err);
    return res.status(500).json({ error: 'Failed to load orders.' });
  }
};

/**
 * POST /api/vendor/orders
 *
 * Body: { title, clientId?, schoolName, stage?, progress?, totalCards?,
 *         completedCards?, deliveryDate?, productType?, vendorId }
 */
exports.createOrder = async (req, res) => {
  try {
    const {
      title, clientId, schoolName, stage, progress,
      totalCards, completedCards, deliveryDate, productType, vendorId,
      productName, pricing,
    } = req.body;

    if (!title || !schoolName || !vendorId) {
      return res.status(400).json({ error: 'title, schoolName and vendorId are required.' });
    }

    const order = await Order.create({
      title,
      schoolName,
      stage:          stage          || 'Draft',
      progress:       progress       || 0,
      totalCards:     totalCards     || 0,
      completedCards: completedCards || 0,
      vendorId,
      ...(clientId    && { clientId }),
      ...(deliveryDate && { deliveryDate: new Date(deliveryDate) }),
      ...(productType  && { productType }),
      ...(productName  && { productName }),
      ...(pricing      && { pricing }),
    });

    return res.status(201).json({
      id:         order._id,
      title:      order.title,
      schoolName: order.schoolName,
      stage:      order.stage,
      progress:   order.progress,
    });
  } catch (err) {
    console.error('[createOrder]', err);
    return res.status(500).json({ error: 'Failed to create order.' });
  }
};

/**
 * GET /api/vendor/clients/:id
 *
 * Returns full details for a single client.
 */
exports.getVendorClientById = async (req, res) => {
  try {
    const client = await Client.findById(req.params.id).lean();
    if (!client) return res.status(404).json({ error: 'Client not found.' });
    return res.json({
      id:          client._id,
      schoolName:  client.schoolName,
      schoolCode:  client.schoolCode || '',
      address:     client.address     || '',
      city:        client.city        || '',
      contactName: client.contactName || '',
      phone:       client.phone       || '',
      email:       client.email       || '',
      vendorId:    client.vendorId,
    });
  } catch (err) {
    console.error('[getVendorClientById]', err);
    return res.status(500).json({ error: 'Failed to load client.' });
  }
};

/**
 * GET /api/vendor/clients/:id/school-summary
 *
 * Returns class / student / teacher counts for the school linked
 * to this client (via client.schoolCode → principal User).
 */
exports.getClientSchoolSummary = async (req, res) => {
  try {
    const client = await Client.findById(req.params.id).lean();
    if (!client) return res.status(404).json({ error: 'Client not found.' });

    const schoolCode = (client.schoolCode || '').toUpperCase();
    if (!schoolCode) {
      return res.json({ classesCount: 0, studentsCount: 0, teachersCount: 0, linked: false });
    }

    const principal = await User.findOne({ role: 'principal', schoolCode }).select('_id').lean();
    if (!principal) {
      return res.json({ classesCount: 0, studentsCount: 0, teachersCount: 0, linked: false });
    }

    const principalId = principal._id.toString();
    const [classesCount, studentsCount, teachersCount] = await Promise.all([
      SchoolClass .countDocuments({ principalId }),
      SchoolMember.countDocuments({ principalId, type: 'student' }),
      SchoolMember.countDocuments({ principalId, type: 'teacher' }),
    ]);

    console.log(`[schoolSummary] school=${schoolCode} classes=${classesCount} students=${studentsCount} teachers=${teachersCount}`);
    return res.json({ classesCount, studentsCount, teachersCount, linked: true, schoolCode });
  } catch (err) {
    console.error('[getClientSchoolSummary]', err);
    return res.status(500).json({ error: 'Failed to load school summary.' });
  }
};

/**
 * GET /api/vendor/clients/:id/orders
 *
 * Returns all orders linked to this client via clientId FK.
 */
exports.getClientOrders = async (req, res) => {
  try {
    const orders = await Order.find({ clientId: req.params.id })
      .sort({ updatedAt: -1 })
      .lean();
    return res.json(orders.map(o => ({
      id:           o._id,
      title:        o.title,
      schoolName:   o.schoolName,
      stage:        o.stage,
      progress:     o.progress,
      productType:  o.productType  || '',
      deliveryDate: o.deliveryDate || null,
      createdAt:    o.createdAt,
    })));
  } catch (err) {
    console.error('[getClientOrders]', err);
    return res.status(500).json({ error: 'Failed to load orders.' });
  }
};

const STAGES = [
  'Draft',
  'Data Upload',
  'Design',
  'Proof',
  'Printing',
  'Dispatch',
  'Delivered',
];

exports.advanceOrderStage = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found.' });
    const idx = STAGES.indexOf(order.stage);
    if (idx === -1 || idx === STAGES.length - 1) {
      return res.status(400).json({ error: 'Order is already at the final stage.' });
    }
    order.stage = STAGES[idx + 1];
    await order.save();
    return res.json({ id: order._id, stage: order.stage });
  } catch (err) {
    console.error('[advanceOrderStage]', err);
    return res.status(500).json({ error: 'Failed to advance stage.' });
  }
};

/**
 * POST /api/vendor/orders/:id/files
 *
 * Attaches uploaded files to an existing order.
 * Accepts multipart/form-data with field name "files" (up to 20 files).
 */
exports.uploadOrderFiles = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found.' });

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files received.' });
    }

    const newEntries = req.files.map((f) => ({
      originalName: f.originalname,
      filename:     f.filename,
      path:         `/uploads/order-files/${f.filename}`,
      mimeType:     f.mimetype,
      size:         f.size,
    }));

    order.files.push(...newEntries);
    await order.save();

    return res.status(201).json({
      orderId:  order._id,
      uploaded: newEntries.length,
      files:    newEntries,
    });
  } catch (err) {
    console.error('[uploadOrderFiles]', err);
    return res.status(500).json({ error: 'Failed to upload files.' });
  }
};

exports.getVendorDashboard = async (req, res) => {
  try {
    const rawVendorId = (req.query.vendorId || '').toString().trim();
    let vendorCode = normalizeVendorCode(req.query.vendorCode);

    if (!rawVendorId && !vendorCode) {
      return res.status(400).json({
        error: 'vendorId or vendorCode query parameter is required.',
      });
    }

    let vendorId = rawVendorId;

    // Allow dashboard lookup by vendorCode when vendorId is not available.
    if (!vendorId && vendorCode) {
      const vendorUser = await User.findOne({
        role: 'vendor',
        vendorCode,
      })
        .select('_id vendorCode')
        .lean();

      if (!vendorUser) {
        return res.status(404).json({ error: 'Vendor not found for provided vendorCode.' });
      }

      vendorId = vendorUser._id.toString();
      vendorCode = normalizeVendorCode(vendorUser.vendorCode);
    }

    // Resolve vendorCode from vendor profile when vendorId is available.
    const isObjectId = /^[a-f\d]{24}$/i.test(vendorId);
    if (!vendorCode && isObjectId) {
      const vendorUser = await User.findById(vendorId)
        .select('vendorCode')
        .lean();
      vendorCode = normalizeVendorCode(vendorUser?.vendorCode);
    }

    // Build start-of-today boundary (UTC midnight)
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);

    // Run all queries in parallel for performance
    const [
      totalClients,
      activeOrders,
      cardsTodayResult,
      activeProjects,
      schools,
      linkedPrincipalSchools,
    ] =
      await Promise.all([
        // 1. Total clients for this vendor
        Client.countDocuments({ vendorId }),

        // 2. Orders that are not yet delivered
        Order.countDocuments({ vendorId, stage: { $ne: 'Delivered' } }),

        // 3. Sum of completedCards from orders updated today (must be tied to a client)
        Order.aggregate([
          {
            $match: {
              vendorId,
              updatedAt: { $gte: todayStart },
              clientId: { $exists: true },
            },
          },
          {
            $group: {
              _id: null,
              total: { $sum: '$completedCards' },
            },
          },
        ]),

        // 4. Latest 5 orders tied to a real client for the active projects board
        Order.find({ vendorId, clientId: { $exists: true } })
          .sort({ updatedAt: -1 })
          .limit(5)
          .select('schoolName stage progress -_id'),

        // 5. All client schools for this vendor
        Client.find({ vendorId })
          .sort({ createdAt: -1 })
          .select('schoolName city -_id'),

        // 6. Schools linked by principal vendorCode
        vendorCode
          ? User.find({ role: 'principal', vendorCode })
              .select('schoolName schoolCode -_id')
              .lean()
          : Promise.resolve([]),
      ]);

    const cardsToday =
      cardsTodayResult.length > 0 ? cardsTodayResult[0].total : 0;

    // Merge schools from vendor clients and principal-vendor linkage.
    const mergedSchools = [];
    const seenSchools = new Set();

    for (const s of schools) {
      const schoolName = (s.schoolName || '').toString().trim();
      const city = (s.city || '').toString().trim();
      const key = schoolName.toLowerCase();
      if (!schoolName || seenSchools.has(key)) continue;
      seenSchools.add(key);
      mergedSchools.push({ schoolName, city });
    }

    for (const p of linkedPrincipalSchools) {
      const schoolName =
        (p.schoolName || p.schoolCode || '').toString().trim();
      const key = schoolName.toLowerCase();
      if (!schoolName || seenSchools.has(key)) continue;
      seenSchools.add(key);
      mergedSchools.push({ schoolName, city: '' });
    }

    return res.json({
      totalClients,
      activeOrders,
      cardsToday,
      activeProjects,
      schools: mergedSchools,
    });
  } catch (err) {
    console.error('[getVendorDashboard]', err);
    return res.status(500).json({ error: 'Failed to load dashboard data.' });
  }
};

// ── Excel Upload + Auto-Ingest ───────────────────────────────────────────────

const excelUploadDir = path.join(__dirname, '..', 'uploads', 'excel-imports');
if (!fs.existsSync(excelUploadDir)) fs.mkdirSync(excelUploadDir, { recursive: true });

const _excelUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, excelUploadDir),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname);
      cb(null, `${Date.now()}-${Math.round(Math.random() * 1e6)}${ext}`);
    },
  }),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (['.xlsx', '.xls', '.csv'].includes(ext)) return cb(null, true);
    cb(new Error('Only .xlsx, .xls, .csv files are allowed'));
  },
});

exports.uploadExcelMiddleware = _excelUpload.single('file');

/**
 * POST /api/vendor/upload-excel
 *
 * multipart/form-data fields:
 *   file      – the Excel / CSV file
 *   mapping   – JSON: { studentName: "colA", className: "colB", ... }
 *   vendorId  – string
 *   clientId  – string (MongoDB _id of Client record)
 *
 * Flow:
 *  1. Parse Excel rows using the provided column mapping
 *  2. Resolve principalId via clientId → Client.schoolCode → User(principal)
 *  3. Bulk-upsert classes (unique: name + principalId)
 *  4. Bulk-upsert students (unique: phone + principalId, fallback: name+class)
 *  5. Bulk-upsert teachers (if teacherName column mapped, unique: name+principalId)
 *  6. Return summary { classesCreated, studentsAdded, teachersAdded }
 */
exports.uploadExcel = async (req, res) => {
  const filePath = req.file?.path;
  try {
    const { vendorId, clientId } = req.body || {};
    if (!req.file) return res.status(400).json({ error: 'No file uploaded.' });
    if (!clientId) return res.status(400).json({ error: 'clientId is required.' });

    // Parse mapping
    let mapping = {};
    try {
      mapping = JSON.parse(req.body.mapping || '{}');
    } catch {
      return res.status(400).json({ error: 'Invalid mapping JSON.' });
    }

    // ── Parse Excel / CSV ──────────────────────────────────────────
    const workbook = XLSX.readFile(filePath);
    const sheet    = workbook.Sheets[workbook.SheetNames[0]];
    // header:1 → first row as header, defval:'', raw:false → all strings
    const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '', raw: false });
    if (rows.length < 2) {
      return res.status(422).json({ error: 'File has no data rows.' });
    }

    // Build column-index lookup from first row (headers)
    const headerRow = rows[0].map(h => (h || '').toString().trim());
    console.log('[uploadExcel] Headers:', headerRow);
    console.log('[uploadExcel] Mapping:', mapping);

    // Mapped field → column index (from user-provided mapping)
    const colIndex = {};
    for (const [fieldKey, excelColName] of Object.entries(mapping)) {
      if (!excelColName) continue;
      const idx = headerRow.findIndex(
        h => h.toLowerCase() === (excelColName || '').toLowerCase()
      );
      if (idx !== -1) colIndex[fieldKey] = idx;
    }

    // Raw column name (lowercased, stripped) → index — used as fallback
    const rawIdx = {};
    headerRow.forEach((h, i) => {
      if (h) rawIdx[h.toLowerCase().replace(/[\s_]/g, '')] = i;
    });

    // Common raw column name aliases for each semantic field
    const _fallbacks = {
      studentName: ['studentname', 'student'],
      firstName:   ['firstname', 'first', 'fname'],
      lastName:    ['lastname', 'last', 'lname', 'surname'],
      className:   ['classname', 'class', 'grade', 'std', 'standard'],
      section:     ['section', 'sec'],
      rollNumber:  ['rollnumber', 'rollno', 'roll', 'admno', 'admissionno', 'srno', 'sr', 'regno', 'reg'],
      dob:         ['dob', 'dateofbirth', 'birthdate', 'birth', 'birthdt'],
      parentName:  ['parentname', 'fathername', 'father', 'guardian', 'parent'],
      phone:       ['phone', 'mobile', 'fathermobno', 'fathermobile', 'mob', 'mobileno', 'phoneno', 'contact', 'fatherno'],
      address:     ['address', 'addr'],
      teacherName: ['teachername', 'teacher'],
    };

    // Helper: cell value — mapped field first, then raw-column fallback
    const cell = (row, key) => {
      if (colIndex[key] !== undefined) {
        return (row[colIndex[key]] || '').toString().trim();
      }
      for (const fb of (_fallbacks[key] || [])) {
        if (rawIdx[fb] !== undefined) return (row[rawIdx[fb]] || '').toString().trim();
      }
      return '';
    };

    const dataRows = rows.slice(1).filter(r => r.some(c => (c || '').toString().trim()));
    console.log('[uploadExcel] Data rows:', dataRows.length);

    // ── Resolve principalId from the SELECTED client only ─────────
    // Never trust the Excel file's schoolCode column — always use
    // the school the vendor explicitly selected in the UI.
    const client = await Client.findById(clientId).lean();
    if (!client) return res.status(404).json({ error: 'Client not found.' });

    const selectedSchoolCode = (client.schoolCode || '').toUpperCase();
    console.log(`[uploadExcel] Saving for school: ${selectedSchoolCode} (clientId=${clientId})`);

    if (!selectedSchoolCode) {
      return res.status(422).json({
        error: 'The selected client has no school code. Please update the client and add a school code first.',
      });
    }

    const principalUser = await User.findOne({
      role: 'principal',
      schoolCode: selectedSchoolCode,
    }).select('_id').lean();

    if (!principalUser) {
      return res.status(422).json({
        error: `No principal account found for school code "${selectedSchoolCode}". Please ensure the principal is registered first.`,
      });
    }

    const principalId = principalUser._id.toString();
    console.log(`[uploadExcel] principalId resolved: ${principalId}`);

    // ── Build data sets ────────────────────────────────────────────
    const classSet     = new Map(); // key → { name, principalId }
    const studentList  = [];       // { type, name, classOrDept, phone, ... }
    const teacherMap   = new Map(); // teacherName → Set of classes

    for (const row of dataRows) {
      const className  = cell(row, 'className');
      const section    = cell(row, 'section');
      const fullClass  = section ? `${className} - ${section}` : className;

      if (className) {
        const classKey = fullClass.toLowerCase();
        if (!classSet.has(classKey)) classSet.set(classKey, fullClass);
      }

      // Student name: always try firstName + lastName first (most Excel files split them),
      // then fall back to the studentName mapping if neither part is present.
      const firstName = cell(row, 'firstName');
      const lastName  = cell(row, 'lastName');
      let studentName = (firstName || lastName)
        ? `${firstName} ${lastName}`.trim()
        : cell(row, 'studentName');

      console.log(`[uploadExcel] Row student – firstName="${firstName}" lastName="${lastName}" resolved="${studentName}" class="${fullClass}"`);

      // Push the student even when some fields are missing; only skip truly blank rows
      if (studentName || fullClass) {
        studentList.push({
          type:        'student',
          name:        studentName || 'Unknown',
          classOrDept: fullClass,
          phone:       cell(row, 'phone'),
          address:     cell(row, 'address'),
          principalId,
        });
      }

      const teacherName = cell(row, 'teacherName');
      if (teacherName) {
        if (!teacherMap.has(teacherName)) teacherMap.set(teacherName, new Set());
        if (fullClass) teacherMap.get(teacherName).add(fullClass);
      }
    }

    // ── Bulk upsert classes ────────────────────────────────────────
    let classesCreated = 0;
    const classBulk = [...classSet.values()].map(name => ({
      updateOne: {
        filter: { name, principalId },
        update: { $setOnInsert: { name, principalId } },
        upsert: true,
      },
    }));
    if (classBulk.length) {
      await SchoolClass.bulkWrite(classBulk, { ordered: false });
      // Count all unique classes found in the file (new OR already existing)
      classesCreated = classBulk.length;
    }

    // ── Bulk upsert students ───────────────────────────────────────
    let studentsAdded = 0;
    if (studentList.length) {
      const studentBulk = studentList.map(s => ({
        updateOne: {
          filter: s.phone
            ? { type: 'student', phone: s.phone, principalId }
            : { type: 'student', name: s.name, classOrDept: s.classOrDept, principalId },
          update: {
            $setOnInsert: { type: s.type, principalId },
            $set: { name: s.name, classOrDept: s.classOrDept, phone: s.phone, address: s.address },
          },
          upsert: true,
        },
      }));
      const r = await SchoolMember.bulkWrite(studentBulk, { ordered: false });
      // upsertedCount = truly new records; matchedCount = existing updated
      studentsAdded = r.upsertedCount + (r.matchedCount || 0);
      console.log(`[uploadExcel] students bulkWrite: upserted=${r.upsertedCount} matched=${r.matchedCount} total=${studentsAdded}`);
    }

    // ── Bulk upsert teachers ───────────────────────────────────────
    let teachersAdded = 0;
    if (teacherMap.size) {
      const teacherBulk = [...teacherMap.entries()].map(([name, classes]) => {
        const classOrDept = [...classes].join(', ');
        return {
          updateOne: {
            filter: { type: 'teacher', name, principalId },
            update: { $setOnInsert: { type: 'teacher', name, classOrDept, principalId } },
            upsert: true,
          },
        };
      });
      const r = await SchoolMember.bulkWrite(teacherBulk, { ordered: false });
      teachersAdded = r.upsertedCount;
    }

    // Clean up temp file
    fs.unlink(filePath, () => {});

    console.log(`[uploadExcel] clientId=${clientId} principalId=${principalId} classes=${classesCreated} students=${studentsAdded} teachers=${teachersAdded}`);
    return res.json({
      success: true,
      classesCreated,
      studentsAdded,
      teachersAdded,
      totalRows: dataRows.length,
    });
  } catch (err) {
    console.error('[uploadExcel]', err);
    if (filePath) fs.unlink(filePath, () => {});
    return res.status(500).json({ error: 'Failed to process Excel file.' });
  }
};

/**
 * GET /api/vendor/debug/school?clientId=<id>
 * Diagnostic endpoint – returns raw DB counts for the school linked to a client.
 */
exports.debugSchoolData = async (req, res) => {
  try {
    const { clientId } = req.query;
    if (!clientId) return res.status(400).json({ error: 'clientId required' });

    const Client      = require('../models/Client');
    const SchoolClass  = require('../models/SchoolClass');
    const SchoolMember = require('../models/SchoolMember');
    const User         = require('../models/User');

    const client = await Client.findById(clientId).lean();
    if (!client) return res.status(404).json({ error: 'Client not found' });

    const schoolCode = (client.schoolCode || '').toUpperCase();
    const principal  = schoolCode
      ? await User.findOne({ role: 'principal', schoolCode }).select('_id schoolCode name').lean()
      : null;

    const principalId = principal ? principal._id.toString() : null;

    const memberBreakdown = principalId
      ? await SchoolMember.aggregate([
          { $match: { principalId } },
          { $group: { _id: '$type', count: { $sum: 1 } } },
        ])
      : [];

    const classCount = principalId
      ? await SchoolClass.countDocuments({ principalId })
      : 0;

    const sampleStudents = principalId
      ? await SchoolMember.find({ principalId, type: 'student' }).limit(3).select('name classOrDept phone principalId type').lean()
      : [];

    const sampleWithoutType = principalId
      ? await SchoolMember.find({ principalId, type: { $exists: false } }).limit(3).lean()
      : [];

    return res.json({
      clientSchoolCode: client.schoolCode,
      normalizedSchoolCode: schoolCode,
      principal: principal ? { id: principal._id, name: principal.name, schoolCode: principal.schoolCode } : null,
      principalId,
      classCount,
      memberBreakdown,
      sampleStudents,
      sampleWithoutType,
    });
  } catch (err) {
    console.error('[debugSchoolData]', err);
    return res.status(500).json({ error: err.message });
  }
};

/**
 * GET /api/vendor/schools?vendorId=<id>&search=<query>
 *
 * Returns the list of schools (clients) this vendor has registered,
 * optionally filtered by a search string (matches schoolName or schoolCode).
 * Used by the Quick Capture Setup screen's school selector.
 *
 * Response: [ { id, name, code } ]
 */
exports.getVendorSchools = async (req, res) => {
  try {
    const { vendorId, search } = req.query;
    if (!vendorId) {
      return res.status(400).json({ error: 'vendorId is required.' });
    }

    const filter = { vendorId };

    if (search && search.trim()) {
      const regex = new RegExp(search.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [
        { schoolName: regex },
        { schoolCode: regex },
      ];
    }

    const clients = await Client.find(filter)
      .sort({ schoolName: 1 })
      .select('schoolName schoolCode')
      .lean();

    return res.json(
      clients.map(c => ({
        id:   c._id.toString(),
        name: c.schoolName,
        code: c.schoolCode || '',
      }))
    );
  } catch (err) {
    console.error('[getVendorSchools]', err);
    return res.status(500).json({ error: err.message || 'Failed to load schools.' });
  }
};
