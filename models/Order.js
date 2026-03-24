const mongoose = require('mongoose');

const VALID_STAGES = [
  'Draft',
  'Data Upload',
  'Design',
  'Proof',
  'Printing',
  'Dispatch',
  'Delivered',
];

const orderSchema = new mongoose.Schema(
  {
    title:          { type: String, required: true, trim: true },
    schoolName:     { type: String, required: true, trim: true },
    stage:          {
      type:    String,
      enum:    VALID_STAGES,
      default: 'Draft',
    },
    progress:       { type: Number, min: 0, max: 100, default: 0 },
    totalCards:     { type: Number, min: 0, default: 0 },
    completedCards: { type: Number, min: 0, default: 0 },
    vendorId:       { type: String, required: true, index: true },
    clientId:       { type: mongoose.Schema.Types.ObjectId, ref: 'Client', index: true },
    deliveryDate:   { type: Date },
    productType:    { type: String, trim: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Order', orderSchema);
