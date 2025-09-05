const mongoose = require("mongoose");

const itemSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    description: { type: String },
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User" }
  },
  { timestamps: true }
);

itemSchema.index({ title: 1 }); // optimize queries by title

module.exports = mongoose.model("Item", itemSchema);
