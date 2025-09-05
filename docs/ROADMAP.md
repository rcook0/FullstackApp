# Fullstack Project Roadmap  

This document outlines the planned improvements to the Fullstack App, focusing on **Frontend (3)**, **Database (4)**, and **Testing (5)**.  

---

## ✅ Phase 1 – Frontend Enhancements  
**Goal:** Improve usability, modernize architecture, and prepare for production deployment.  

### Features  
- Convert frontend into a **React SPA** with routing.  
- Add **state management** (Redux Toolkit or Context API).  
- Implement **Dark Mode toggle**, persisted in `localStorage`.  
- Integrate **real-time updates** with WebSocket/SSE.  
- Optimize build pipeline with **Dockerfile** changes.  
- Setup **CI/CD** for frontend build & deploy to Azure Static Web Apps.  

**Deliverables:**  
- `frontend/src/App.jsx` with Router & Theme Provider.  
- `frontend/src/store/` for app state.  
- `frontend/src/hooks/` for API & WebSocket integration.  
- Updated `frontend/Dockerfile`.  

---

## ✅ Phase 2 – Database Enhancements  
**Goal:** Add structure, validation, and operational tooling.  

### Features  
- Add **Mongoose schemas** (`User`, `Item`) with validation.  
- Add **indexes** for performance.  
- Expand `mongo-init.js` → conditionally seed data.  
- Create scripts for **backup/restore**:  
  - `scripts/db-backup.sh`  
  - `scripts/db-restore.sh`  

**Deliverables:**  
- `backend/models/User.js`  
- `backend/models/Item.js`  
- Expanded `mongo-init.js`  
- `scripts/` folder with backup/restore scripts.  

---

## ✅ Phase 3 – Testing Enhancements  
**Goal:** Build confidence through automated testing across stack.  

### Features  
- **Backend**: Jest + Supertest for API route tests.  
- **Frontend**: React Testing Library + Jest.  
- **E2E**: Cypress/Playwright for full integration tests.  
- Update CI/CD workflow to **run tests before deployment**.  

**Deliverables:**  
- `backend/tests/api.test.js`  
- `frontend/src/__tests__/App.test.jsx`  
- `tests/e2e/` with E2E tests.  
- Update `.github/workflows/deploy.yml`.  

---

## 🔮 Future Phases (Optional)  
- Authentication (JWT/OAuth).  
- Blue/Green or Canary deployments.  
- Prometheus/Grafana observability.  
- Role-based access control (RBAC).  
