FROM node:20-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache sqlite sqlite-dev python3 make g++

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application files
COPY . .

# Create data directory with proper permissions
RUN mkdir -p /data \
    && chown -R node:node /data /app

# Switch to non-root user
USER node

EXPOSE 8000

CMD ["npm", "start"]
