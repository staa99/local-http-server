FROM nginx:1.27-alpine

# Copy config file
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Copy njs scripts
COPY njs /etc/nginx/njs

WORKDIR /app

ARG LHS_CONFIG_FILE=config.json
ENV LHS_CONFIG_FILE=${LHS_CONFIG_FILE}