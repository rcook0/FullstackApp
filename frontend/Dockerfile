# --- Stage 1: Build React app ---
FROM node:18 AS build
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy source and build
COPY . .
RUN npm run build

# --- Stage 2: Serve with Nginx ---
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Remove default nginx index page
RUN rm -rf ./*

# Copy built React app from builder
COPY --from=build /app/build .

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
