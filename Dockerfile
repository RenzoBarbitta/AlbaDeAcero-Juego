FROM node:22-alpine
WORKDIR /app
COPY server/package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY server/relay.cjs ./
ENV PORT=8787
EXPOSE 8787
USER node
CMD ["node", "relay.cjs"]
