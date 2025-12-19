# syntax=docker.io/docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6

FROM oven/bun:1.3.5-alpine@sha256:7156fcc0cee0194d390bfaf7f0eeda9a5e383e70cc90f31aad3a2440a033d7dc AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

ENV LEFTHOOK=0

# Install dependencies based on the preferred package manager
COPY package.json bun.lock ./

RUN bun install --frozen-lockfile

FROM base AS prod-deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

ENV LEFTHOOK=0

# Install dependencies based on the preferred package manager
COPY package.json bun.lock ./

RUN bun install --production --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN bun run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 solidstart

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=prod-deps --chown=solidstart:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=solidstart:nodejs /app/.output ./.output
COPY --from=builder --chown=solidstart:nodejs /app/.vinxi ./vinxi

USER solidstart

EXPOSE 3000

ENV PORT=3000

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
ENV HOSTNAME="0.0.0.0"
CMD ["./node_modules/.bin/vinxi", "start"]
