#!/usr/bin/env bash
# Render build script — installs backend + frontend deps, builds frontend
set -o errexit

# Backend dependencies
pip install -r backend/requirements.txt

# Frontend build
cd frontend
npm install
npm run build
cd ..

# Initialize the database (creates tables + seeds data)
cd backend
python -c "from init_db import create_tables, seed_data; create_tables(); seed_data()"
cd ..
