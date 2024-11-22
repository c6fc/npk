# Use the official Node.js 17 image as base
FROM node:17.0.1

# Update and install required packages
RUN apt-get update
RUN apt-get install -y cmake build-essential zip git less
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Switch to the non-root user
USER node

# Set the working directory
WORKDIR /home/node

# Install npm dependencies
#RUN npm install

# Set the entrypoint for the container
ENTRYPOINT ["/usr/local/bin/npm", "run"]
