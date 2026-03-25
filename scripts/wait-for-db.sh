#!/bin/bash
set -e

# Run Prisma migrations
cd slora-core
npx prisma migrate deploy
npx prisma generate

# Start app
cd ..
npm run start