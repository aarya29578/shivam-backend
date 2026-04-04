const express = require('express');
const router  = express.Router();

const {
  getVendorDashboard,
  getVendorOrders,
  getVendorClients,
  getVendorClientById,
  getClientOrders,
  createOrder,
  createClient,
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

module.exports = router;
