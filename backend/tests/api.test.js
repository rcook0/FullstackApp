
const request = require("supertest");
const app = require("../app"); // assuming app.js exports Express app

describe("API Routes", () => {
  it("should return 200 for /api/health", async () => {
    const res = await request(app).get("/api/health");
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe("ok");
  });
});
