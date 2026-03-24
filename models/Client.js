const mongoose = require('mongoose');

const clientSchema = new mongoose.Schema(
  {
    schoolName:  { type: String, required: true, trim: true },
    address:     { type: String, trim: true },
    city:        { type: String, trim: true },
    contactName: { type: String, trim: true },
    phone:       { type: String, trim: true },
    email:       {
      type: String,
      trim: true,
      lowercase: true,
      match: [/^\S+@\S+\.\S+$/, 'Invalid email format'],
    },
    vendorId:    { type: String, required: true, index: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Client', clientSchema);
