# Trainee Full-Stack Application

This project is a complete full-stack application built with Node.js/Express (Backend) and React/Vite (Frontend). It follows clean architecture principles and a production-ready folder structure suitable for future Dockerization and Kubernetes deployment.

## Prerequisites
- Node.js (Latest LTS recommended)
- MySQL Database

## 1. Database Setup
First, create your MySQL database and table. You can use the provided `database_setup.sql` script or run the following:

```sql
CREATE DATABASE trainee_db;
USE trainee_db;
CREATE TABLE students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    department TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 2. Backend Setup
1. Open a terminal and navigate to the backend folder:
   ```bash
   cd trainee_backend
   ```
2. Ensure your `.env` file exists with the following structure (update credentials as needed):
   ```
   DB_HOST=localhost
   DB_USER=root
   DB_PASSWORD=yourpassword
   DB_NAME=trainee_db
   PORT=5000
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Start the backend application:
   ```bash
   npm start
   ```

## 3. Frontend Setup
1. Open a new terminal and navigate to the frontend folder:
   ```bash
   cd trainee_frontend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the Vite React application:
   ```bash
   npm run dev
   ```

## 4. Accessing the Application
- Frontend UI: `http://localhost:5173` (or the port Vite provides)
- Backend API: `http://localhost:5000/api`

## Architecture Highlights
- **Clean Architecture Models:** Separated Controllers, Models, Routes, and Config in backend.
- **Ready for Docker:** `.gitignore` properly set up avoiding node_modules and .env files. Dependencies are locked.
- **RESTful Best Practices:** Employs appropriate HTTP methods, status codes, error handling, and separation of concerns.
- **Modern React:** Component-driven Vite architecture utilizing React Router for clean navigation and Axios for HTTP requests.
