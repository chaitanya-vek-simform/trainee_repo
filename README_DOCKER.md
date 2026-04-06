# Simplified Docker Compose (Hub & Spoke Networking)

This setup uses **Nginx** as the central hub connecting isolated frontend and backend networks.

---

## Architecture

```
Host Machine (Port 8080)
      │
      ▼
[nginx (Gateway)]  ◄─── Bridge
      │
      ├─── (frontend_network) ───▶ [frontend]
      │
      └─── (backend_network) ────▶ [backend]
                                     └───▶ [database]
```

---

## 🔒 Network Isolation

- **`frontend_network`**: Contains `nginx` and `frontend`.
- **`backend_network`**: Contains `nginx`, `backend`, and `database`.
- **Logic**: Nginx is the only "Dual-Homed" service. The Frontend cannot see the Backend, and the Database is doubly-shielded.

---

## 🚀 Run & Access

```bash
docker compose up -d --build
```

- **Web App**: [http://localhost:8080](http://localhost:8080)

---

## 🛠️ Management

```bash
docker compose ps
docker compose logs -f
docker compose down
```
