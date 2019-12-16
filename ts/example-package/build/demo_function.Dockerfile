FROM node:10-alpine as builder

RUN mkdir -p /home/node/app && \
    chown -R node:node /home/node/app

# Run as non-root user as a best-practices:
# https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md
USER node

WORKDIR /home/node/app

# TODO(b/141115380): Remove this hack when NPM packages are published.
COPY --chown=node:node /deps/kpt-functions/kpt-functions-0.0.1.tgz /deps/kpt-functions/kpt-functions-0.0.1.tgz

# Install dependencies and cache them.
COPY --chown=node:node package.json ./
# TODO(b/141115380): Include package-lock.json from host and run 'npm ci' instead.
RUN npm install

# Build the source.
COPY --chown=node:node tsconfig.json .
COPY --chown=node:node src src
RUN npm run build && \
    npm prune --production

#############################################

FROM node:10-alpine

USER node
WORKDIR /home/node/app

COPY --from=builder /home/node/app /home/node/app

ENTRYPOINT ["node", "/home/node/app/dist/demo_function_run.js"]