const Client = require('../models/Client');
const Order  = require('../models/Order');

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
    const { schoolName, address, city, contactName, phone, email, vendorId } = req.body || {};
    if (!schoolName || !vendorId) {
      return res.status(400).json({ error: 'schoolName and vendorId are required.' });
    }
    const client = await Client.create({
      schoolName,
      vendorId,
      ...(address     && { address }),
      ...(city        && { city }),
      ...(contactName && { contactName }),
      ...(phone       && { phone }),
      ...(email       && { email }),
    });
    return res.status(201).json({
      id:          client._id,
      schoolName:  client.schoolName,
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

exports.getVendorDashboard = async (req, res) => {
  try {
    const { vendorId } = req.query;

    if (!vendorId) {
      return res.status(400).json({ error: 'vendorId query parameter is required.' });
    }

    // Build start-of-today boundary (UTC midnight)
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);

    // Run all queries in parallel for performance
    const [totalClients, activeOrders, cardsTodayResult, activeProjects, schools] =
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
      ]);

    const cardsToday =
      cardsTodayResult.length > 0 ? cardsTodayResult[0].total : 0;

    return res.json({
      totalClients,
      activeOrders,
      cardsToday,
      activeProjects,
      schools,
    });
  } catch (err) {
    console.error('[getVendorDashboard]', err);
    return res.status(500).json({ error: 'Failed to load dashboard data.' });
  }
};
