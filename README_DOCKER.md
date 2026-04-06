# Docker Compose Setup — Trainee Full-Stack Application

This documents how to run the entire application stack using **Docker Compose** with a simplified single-port entry point.

---

## Architecture Overview

```
Host Machine (Port 80)
      │
      ▼
[nginx (Gateway)]
      │
      ├───▶ [frontend (Static UI)]
      │
      └───▶ [backend (API Logic)]
               │
               └───▶ [database (MySQL)]
```

| Service    | Port (Internal) | Port (Host) | Purpose                         | Network(s)          |
| :--------- | :-------------- | :---------- | :------------------------------ | :------------------ |
| **`nginx`**    | 80              | **80**      | Single Gateway Point            | `frontend_net`      |
| `frontend` | 80              | -           | Static React server             | `frontend_net`      |
| `backend`  | 5000            | -           | Node.js API                     | `frontend_net`, `backend_net` |
| `database` | 3306            | -           | MySQL persistence               | `backend_net`       |

---

## 🔒 Network Isolation

We use two primary networks:
1.  **`frontend_net`**: Connects `nginx`, `frontend`, and `backend`. Used for all web and API traffic.
2.  **`backend_net`**: **Strictly isolates** the `database` from everything except the `backend` service.

---

## 🚀 How to Run

### 1. Build and Start the Stack

```bash
docker compose up -d --build
```

### 2. Verify Access

- **Web App (UI & API)**: [http://localhost:8080](http://localhost:8080) (using mapped port 8080)

---

## 🛠️ Management Commands

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Shut down the stack
docker compose down
```

---

## ⚙️ Environment Configuration

Edit these files locally before building:
- **`database.env`**: MySQL root/user credentials.
- **`trainee_backend/.env`**: Backend to Database connection strings.
- **`trainee_frontend/Dockerfile`**: Build-time API URL (`VITE_API_URL=/api`).
