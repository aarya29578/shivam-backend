const SchoolClass  = require('../models/SchoolClass');
const SchoolMember = require('../models/SchoolMember');

// ── Classes ──────────────────────────────────────────────────────────────────

exports.getClasses = async (req, res) => {
  try {
    const { principalId } = req.query;
    if (!principalId) return res.status(400).json({ error: 'principalId required' });
    const list = await SchoolClass.find({ principalId }).sort({ createdAt: 1 }).lean();
    return res.json(list.map(c => ({ id: c._id, name: c.name })));
  } catch (err) {
    console.error('[getClasses]', err);
    return res.status(500).json({ error: 'Failed to load classes.' });
  }
};

exports.createClass = async (req, res) => {
  try {
    const { name, principalId } = req.body || {};
    if (!name || !principalId) return res.status(400).json({ error: 'name and principalId required' });
    const c = await SchoolClass.create({ name, principalId });
    return res.status(201).json({ id: c._id, name: c.name });
  } catch (err) {
    console.error('[createClass]', err);
    return res.status(500).json({ error: 'Failed to create class.' });
  }
};

exports.deleteClass = async (req, res) => {
  try {
    await SchoolClass.findByIdAndDelete(req.params.id);
    return res.json({ message: 'Class deleted.' });
  } catch (err) {
    console.error('[deleteClass]', err);
    return res.status(500).json({ error: 'Failed to delete class.' });
  }
};

// ── Members (teachers / students / staff) ────────────────────────────────────

exports.getMembers = async (req, res) => {
  try {
    const { principalId, type } = req.query;
    if (!principalId) return res.status(400).json({ error: 'principalId required' });
    const query = { principalId };
    if (type) query.type = type;
    const list = await SchoolMember.find(query).sort({ createdAt: 1 }).lean();
    return res.json(list.map(m => ({
      id:          m._id,
      name:        m.name,
      classOrDept: m.classOrDept,
      phone:       m.phone,
      address:     m.address,
    })));
  } catch (err) {
    console.error('[getMembers]', err);
    return res.status(500).json({ error: 'Failed to load members.' });
  }
};

exports.createMember = async (req, res) => {
  try {
    const { type, name, classOrDept, phone, address, principalId } = req.body || {};
    if (!type || !name || !principalId)
      return res.status(400).json({ error: 'type, name and principalId required' });
    const m = await SchoolMember.create({
      type,
      name,
      principalId,
      classOrDept: classOrDept || '',
      phone:       phone       || '',
      address:     address     || '',
    });
    return res.status(201).json({
      id:          m._id,
      name:        m.name,
      classOrDept: m.classOrDept,
      phone:       m.phone,
      address:     m.address,
    });
  } catch (err) {
    console.error('[createMember]', err);
    return res.status(500).json({ error: 'Failed to create member.' });
  }
};

exports.updateMember = async (req, res) => {
  try {
    const { name, classOrDept, phone, address } = req.body || {};
    const m = await SchoolMember.findByIdAndUpdate(
      req.params.id,
      { name, classOrDept, phone, address },
      { new: true }
    ).lean();
    if (!m) return res.status(404).json({ error: 'Member not found.' });
    return res.json({
      id:          m._id,
      name:        m.name,
      classOrDept: m.classOrDept,
      phone:       m.phone,
      address:     m.address,
    });
  } catch (err) {
    console.error('[updateMember]', err);
    return res.status(500).json({ error: 'Failed to update member.' });
  }
};

// ── User Management (teachers + staff as app users) ─────────────────────────

exports.getUsers = async (req, res) => {
  try {
    const { principalId } = req.query;
    if (!principalId) return res.status(400).json({ error: 'principalId required' });
    const list = await SchoolMember.find({ principalId, type: { $in: ['teacher', 'staff'] } })
      .sort({ createdAt: 1 }).lean();
    return res.json(list.map(m => ({
      id:           m._id,
      name:         m.name,
      type:         m.type,
      classOrDept:  m.classOrDept,
      phone:        m.phone,
      isRestricted: !!m.isRestricted,
    })));
  } catch (err) {
    console.error('[getUsers]', err);
    return res.status(500).json({ error: 'Failed to load users.' });
  }
};

exports.restrictMember = async (req, res) => {
  try {
    const { isRestricted } = req.body || {};
    const m = await SchoolMember.findByIdAndUpdate(
      req.params.id,
      { isRestricted: !!isRestricted },
      { new: true }
    ).lean();
    if (!m) return res.status(404).json({ error: 'Member not found.' });
    return res.json({ id: m._id, isRestricted: m.isRestricted });
  } catch (err) {
    console.error('[restrictMember]', err);
    return res.status(500).json({ error: 'Failed to update restriction.' });
  }
};

exports.forceLogoutMember = async (req, res) => {
  try {
    const m = await SchoolMember.findById(req.params.id).lean();
    if (!m) return res.status(404).json({ error: 'Member not found.' });
    // In a full auth system, invalidate token here.
    return res.json({ message: 'User force logged out.' });
  } catch (err) {
    console.error('[forceLogoutMember]', err);
    return res.status(500).json({ error: 'Failed to force logout.' });
  }
};

exports.deleteMember = async (req, res) => {
  try {
    await SchoolMember.findByIdAndDelete(req.params.id);
    return res.json({ message: 'Member deleted.' });
  } catch (err) {
    console.error('[deleteMember]', err);
    return res.status(500).json({ error: 'Failed to delete member.' });
  }
};
