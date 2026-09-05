# Build stage
FROM node:20-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .

# Proxy target is baked into Nitro at build time (not runtime .env).
# Docker network service name + container port:
ARG NUXT_API_PROXY=http://api:8000
ENV NUXT_API_PROXY=$NUXT_API_PROXY

RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app
COPY --from=build /app/.output ./.output
COPY package.json ./

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
ENV NUXT_PUBLIC_API_BASE=

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]
