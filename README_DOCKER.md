# Docker Compose Setup — Trainee Full-Stack Application

This documents how to run the entire application stack using **Docker Compose** with 4 distinct services and network isolation.

---

## Architecture Overview

```
Host Machine
├── :5001  ──▶  [nginx (Gateway)]  ──▶  [frontend (Port 80)]
└── :5000  ──▶  [nginx (Gateway)]  ──▶  [backend (Port 5000)]
                                         └──▶ [database (Port 3306)]
```

| Service    | Port (Internal) | Port (Host) | Purpose                         | Network(s)          |
| :--------- | :-------------- | :---------- | :------------------------------ | :------------------ |
| `database` | 3306            | -           | MySQL persistence               | `backend_net`       |
| `backend`  | 5000            | -           | Node.js API                     | `backend_net`, `frontend_net` |
| `frontend` | 80              | -           | Static React server             | `frontend_net`      |
| `nginx`    | 5000, 5001      | 5000, 5001  | Central gateway proxy           | `frontend_net`      |

---

## 🔒 Network Isolation

We use two primary networks for security:
1.  **`backend_net`**: Only the `database` and `backend` services can communicate. The database is shielded from the frontend and the gateway.
2.  **`frontend_net`**: Used for `nginx` gateway to route requests to either the `frontend` or `backend` services.

---

## 🚀 How to Run

### 1. Build and Start the Stack

```bash
docker-compose up -d --build
```

### 2. Verify Access

- **Frontend UI**: [http://localhost:5001](http://localhost:5001)
- **Backend API**: [http://localhost:5000/api](http://localhost:5000/api)

---

## 🛠️ Management Commands

```bash
# Check service status
docker-compose ps

# View logs for all services
docker-compose logs -f

# Stop and remove containers
docker-compose down

# Stop, remove containers, and delete volumes (warning: deletes DB data)
docker-compose down -v

# Rebuild a single service (e.g. after code changes)
docker-compose up -d --build backend
```

---

## ⚙️ Environment Configuration

- **`database.env`**: Controls the `database` container (MySQL user/password).
- **`trainee_backend/.env`**: Controls the `backend` container (API port, database connection details).

Both are gitignored so sensitive info never leaves your local machine.
