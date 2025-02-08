FROM node:20-alpine

# Install build dependencies
RUN apk add --no-cache python3 make g++ sqlite sqlite-dev

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Create data directory
RUN mkdir -p /data && chown -R node:node /data /app

# Switch to non-root user
USER node

EXPOSE 8000
CMD ["npm", "start"]
