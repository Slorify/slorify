#!/bin/bash
set -e

echo "👉 Installing prerequisites..."

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
  echo "🔹 Docker not found — installing..."
  curl -fsSL https://get.docker.com | sh
fi

# Install Docker Compose plugin if not installed
if ! docker compose version &> /dev/null; then
  echo "🔹 Docker Compose plugin not found — installing..."
  sudo apt update
  sudo apt install -y docker-compose-plugin
fi

# Add current user to docker group (so you don’t need sudo each time)
sudo usermod -aG docker $USER

echo "👉 Cloning repository..."
if [ -d slorify ]; then
  echo "⚠️ slorify directory already exists, skipping clone"
else
  git clone https://github.com/Slorify/slorify.git
fi

cd slorify

echo "👉 Setting up environment variables"
# Create .env file if not exists
cat <<EOF > .env
NODE_ENV=production
DATABASE_URL=postgres://slora:slorapass@db:5432/sloraDB
EOF

echo "👉 Running all containers and migrations..."
docker compose up -d

echo "✅ Slorify installed and running!"
echo "🌐 Visit http://localhost:4000"