# Use the official Node.js 17 image as base
FROM node:17

# Update and install required packages
RUN apt-get update && \
    apt-get install -y cmake build-essential awscli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch to the non-root user
USER node

# Set the working directory
WORKDIR /home/node

# Clone the npk repository
RUN git clone https://github.com/c6fc/npk.git

# Set the working directory
WORKDIR /home/node/npk

# Install npm dependencies
RUN npm install

# Set the entrypoint for the container
ENTRYPOINT ["/usr/local/bin/npm", "run"]
