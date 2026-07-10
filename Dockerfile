FROM ruby:3.3.11 AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    SECRET_KEY_BASE=dummy

WORKDIR /opt/decidim

RUN apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && apt-get install -y nodejs \
    build-essential \
    postgresql-client \
    p7zip \
    libpq-dev && \
    apt-get clean

COPY package.json  ./package.json
COPY package-lock.json ./package-lock.json
COPY packages ./packages/

RUN npm ci

COPY Gemfile Gemfile.lock ./

RUN bundle install --jobs="$(nproc)" --retry=3

COPY . .

RUN bin/rails assets:precompile && \
    bin/rails deface:precompile && \
    bin/rails decidim_api:generate_docs

RUN gem install bundler:$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1 | xargs) && \
    bundle config set --deployment true && \
    bundle config set --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    npm install yarn -g && \
    # Remove unneeded gems
    bundle clean --force && \
    # Remove unneeded files from installed gems (cache, *.o, *.c)
    rm -rf /usr/local/bundle/cache && \
    find /usr/local/bundle/ -name "*.c" -delete && \
    find /usr/local/bundle/ -name "*.o" -delete && \
    find /usr/local/bundle/ -name ".git" -exec rm -rf {} + && \
    find /usr/local/bundle/ -name ".github" -exec rm -rf {} + && \
    # Remove additional unneeded decidim files
    find /usr/local/bundle/bundler/gems/ -type d -name "spec" -prune -exec rm -rf {} + && \
    find /usr/local/bundle/bundler/gems/decidim-* -type d -name "db/migrate" -prune -exec rm -rf {} + && \
    find /usr/local/bundle/bundler/gems/decidim-* -type d -name "docs" -prune -exec rm -rf {} + && \
    find /usr/local/bundle/ -name "spec" -exec rm -rf {} + && \
    find /usr/local/bundle/ -wholename "*/decidim-dev/lib/decidim/dev/assets/*" -exec rm -rf {} +


FROM ruby:3.3.11-slim AS runner

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    NODE_ENV=production \
    SECRET_KEY_BASE=dummy \
    LD_PRELOAD="libjemalloc.so.2" \
    MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:5000,muzzy_decay_ms:5000,narenas:2"

RUN apt-get update && \
    apt-get install --no-install-recommends -y postgresql-client \
    imagemagick \
    curl \
    p7zip \
    libjemalloc2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 decidim && \
    useradd --uid 1000 --gid decidim --create-home --shell /bin/bash decidim

WORKDIR /opt/decidim

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /opt/decidim /opt/decidim

RUN chown -R decidim:decidim /opt/decidim
USER decidim

HEALTHCHECK --interval=1m --timeout=5s --start-period=30s \
    CMD (curl -sS http://localhost:3000/up | grep green) || exit 1

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
