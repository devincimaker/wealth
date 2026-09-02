FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY tsconfig.json ./

EXPOSE 3002
ENV NODE_ENV=production
ENV PORT=3002

CMD ["npm", "start"]
