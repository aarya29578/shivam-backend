const express = require('express');
const router  = express.Router();

const {
  getVendorDashboard,
  getVendorOrders,
  getVendorClients,
  getVendorClientById,
  getClientOrders,
  getClientSchoolSummary,
  createOrder,
  createClient,
  updateClient,
  deleteClient,
  advanceOrderStage,
  uploadOrderFiles,
  uploadOrderFilesMiddleware,
  uploadExcel,
  uploadExcelMiddleware,
} = require('../controllers/vendorController');

// GET  /api/vendor/dashboard?vendorId=<id>
router.get('/dashboard', getVendorDashboard);

// GET  /api/vendor/orders?vendorId=<id>
router.get('/orders', getVendorOrders);

// POST /api/vendor/orders
router.post('/orders', createOrder);

// GET  /api/vendor/clients?vendorId=<id>
router.get('/clients', getVendorClients);

// POST /api/vendor/clients
router.post('/clients', createClient);

// GET  /api/vendor/clients/:id
router.get('/clients/:id', getVendorClientById);

// PATCH /api/vendor/clients/:id
router.patch('/clients/:id', updateClient);

// GET  /api/vendor/clients/:id/school-summary
router.get('/clients/:id/school-summary', getClientSchoolSummary);

// GET  /api/vendor/clients/:id/orders
router.get('/clients/:id/orders', getClientOrders);

// DELETE /api/vendor/clients/:id
router.delete('/clients/:id', deleteClient);

// PATCH /api/vendor/orders/:id/advance  – move order to next stage
router.patch('/orders/:id/advance', advanceOrderStage);

// POST /api/vendor/orders/:id/files  – attach files to an existing order
router.post('/orders/:id/files', uploadOrderFilesMiddleware, uploadOrderFiles);

// POST /api/vendor/upload-excel  – parse Excel and auto-ingest classes/students/teachers
router.post('/upload-excel', uploadExcelMiddleware, uploadExcel);

// GET /api/vendor/debug/school?clientId=<id>  – diagnostic counts
const { debugSchoolData, getVendorSchools } = require('../controllers/vendorController');
router.get('/debug/school', debugSchoolData);

// GET /api/vendor/schools?vendorId=<id>&search=<query>  – school selector for Quick Capture
router.get('/schools', getVendorSchools);

module.exports = router;
