FROM node:20-bookworm

RUN apt-get update && apt-get install -y \
    ca-certificates \
    docker.io \
    docker-compose-v2 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /Slorify

RUN corepack enable && corepack prepare pnpm@10.28.2 --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY slora-core/package.json slora-core/package.json
COPY slora-portal/package.json slora-portal/package.json

ENV CI=true
RUN pnpm install --frozen-lockfile

COPY . ./
RUN pnpm -r build \
 && test -d slora-core/dist \
 && test -d slora-portal/dist

EXPOSE 4000
CMD ["bash", "-lc", "cd slora-core && pnpm exec prisma migrate deploy && pnpm exec prisma generate && cd .. && pnpm --filter slora-core start"]
