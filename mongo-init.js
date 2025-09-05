js

db = db.getSiblingDB("fullstack_app");

// Seed users
if (db.users.countDocuments() === 0) {
  db.users.insertMany([
    {
      name: "Admin User",
      email: "admin@example.com",
      password: "admin123", // hash in production
      role: "admin"
    },
    {
      name: "Test User",
      email: "user@example.com",
      password: "user123",
      role: "user"
    }
  ]);
  print("✅ Seeded users collection");
}

// Seed items
if (db.items.countDocuments() === 0) {
  db.items.insertMany([
    { title: "First Item", description: "This is a seeded item." },
    { title: "Second Item", description: "Another example entry." }
  ]);
  print("✅ Seeded items collection");
}


print("✅ MongoDB seed complete");
