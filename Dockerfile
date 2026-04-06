# Stage 1: Build the React frontend
FROM node:18-alpine AS build
WORKDIR /app
COPY trainee_frontend/package*.json ./
RUN npm install
COPY trainee_frontend/ ./
RUN npm run build

# Stage 2: Serve via Nginx
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
# Remove default nginx config and add our custom one
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d

EXPOSE 5000 5001
CMD ["nginx", "-g", "daemon off;"]
