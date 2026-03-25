FROM  node:20-bookworm

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

RUN mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
 | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  bookworm stable" \
  > /etc/apt/sources.list.d/docker.list

RUN apt-get update && apt-get install -y \
    docker-ce-cli \
    docker-compose-plugin \
    docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /Slorify

COPY . ./
# install pnpm
RUN npm install -g pnpm
ENV CI=true
RUN pnpm install --frozen-lockfile --shamefully-hoist
RUN pnpm --filter slora-core exec prisma generate
RUN pnpm --filter slora-core exec prisma migrate deploy
RUN pnpm build

CMD [ "npm", "run", "start" ]
