#!/usr/bin/env bash
set -e

echo "🔹 Installing dependencies for Fullstack App"

# Backend
if [ -d "../backend" ]; then
  echo "➡️ Installing backend dependencies..."
  cd ../backend
  npm install
  echo "✅ Backend dependencies installed"
  cd -
else
  echo "⚠️ Backend folder not found!"
fi

# Frontend
if [ -d "../frontend" ]; then
  echo "➡️ Installing frontend dependencies..."
  cd ../frontend
  npm install
  echo "✅ Frontend dependencies installed"
  cd -
else
  echo "⚠️ Frontend folder not found!"
fi

echo "🎉 All npm dependencies installed!"
