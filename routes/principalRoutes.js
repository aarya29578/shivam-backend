const express = require('express');
const router  = express.Router();
const ctrl    = require('../controllers/principalController');

router.get('/classes',        ctrl.getClasses);
router.post('/classes',       ctrl.createClass);
router.delete('/classes/:id', ctrl.deleteClass);

router.get('/members',                  ctrl.getMembers);
router.post('/members',                 ctrl.createMember);
router.put('/members/:id',              ctrl.updateMember);
router.delete('/members/:id',           ctrl.deleteMember);

router.get('/users',                    ctrl.getUsers);
router.patch('/members/:id/restrict',   ctrl.restrictMember);
router.post('/members/:id/force-logout',ctrl.forceLogoutMember);

module.exports = router;
