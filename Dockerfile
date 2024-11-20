ARG APP_PATH=/opt/outline
FROM node:20-slim AS builder

ARG APP_PATH
WORKDIR $APP_PATH
COPY ./package.json ./yarn.lock ./
COPY ./patches ./patches

RUN yarn install --no-optional --frozen-lockfile --network-timeout 1000000 && \
  yarn cache clean

COPY . .
ARG CDN_URL
RUN yarn build

RUN rm -rf node_modules
RUN yarn install --production=true --frozen-lockfile --network-timeout 1000000 && \
  yarn cache clean

FROM node:20-slim AS runner

LABEL org.opencontainers.image.source="https://github.com/eagletrt/outline"

ARG APP_PATH
WORKDIR $APP_PATH
ENV NODE_ENV=production
ENV PORT=3000
ENV FILE_STORAGE_LOCAL_ROOT_DIR=/var/lib/outline/data

COPY --from=builder $APP_PATH/build ./build
COPY --from=builder $APP_PATH/server ./server
COPY --from=builder $APP_PATH/public ./public
COPY --from=builder $APP_PATH/.sequelizerc ./.sequelizerc
COPY --from=builder $APP_PATH/node_modules ./node_modules
COPY --from=builder $APP_PATH/package.json ./package.json

# Create a non-root user for better security
RUN addgroup --gid 1001 nodejs && \
  adduser --uid 1001 --ingroup nodejs nodejs && \
  mkdir -p $FILE_STORAGE_LOCAL_ROOT_DIR && \
  chown -R nodejs:nodejs $APP_PATH && \
  chown -R nodejs:nodejs $FILE_STORAGE_LOCAL_ROOT_DIR && \
  chmod 1777 $FILE_STORAGE_LOCAL_ROOT_DIR

VOLUME /var/lib/outline/data

USER nodejs
EXPOSE 3000
CMD ["yarn", "start"]
