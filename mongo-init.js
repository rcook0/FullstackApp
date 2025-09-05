
---

## **6️⃣ `mongo-init.js` (sample)**

```js
// mongo-init.js - Seed data for MongoDB
db = db.getSiblingDB('fullstack_app');

db.users.insertMany([
  { username: "admin", password: "admin123", role: "admin" },
  { username: "user1", password: "user123", role: "user" }
]);

db.products.insertMany([
  { name: "Widget", price: 9.99, stock: 100 },
  { name: "Gadget", price: 19.99, stock: 50 }
]);

print("✅ MongoDB seed complete");
