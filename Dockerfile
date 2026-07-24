FROM ruby:3.3.11 AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    SECRET_KEY_BASE=dummy

WORKDIR /opt/decidim

# System dependencies
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      nodejs \
      build-essential \
      libpq-dev \
      postgresql-client \
      p7zip && \
    rm -rf /var/lib/apt/lists/*

# Install the Bundler version required by Gemfile.lock
COPY Gemfile.lock ./

RUN gem install bundler:$(awk '/BUNDLED WITH/{getline;print $1}' Gemfile.lock)

# Install Ruby dependencies
COPY Gemfile ./

RUN bundle config set frozen true && \
    bundle config set deployment true && \
    bundle config set without "development test"

RUN bundle install --jobs=$(nproc) --retry=3

# Install JS dependencies
COPY package.json package-lock.json ./
COPY packages ./packages

RUN npm ci

# Copy application
COPY . .

# Precompile
RUN bundle exec bootsnap precompile --gemfile || true

RUN bin/rails assets:precompile && \
    bin/rails deface:precompile && \
    bin/rails decidim_api:generate_docs

RUN bundle clean --force && \
    rm -rf \
      /usr/local/bundle/cache \
      ~/.bundle \
      ~/.npm \
      node_modules/.cache && \
    find /usr/local/bundle -name "*.c" -delete && \
    find /usr/local/bundle -name "*.o" -delete && \
    find /usr/local/bundle -name ".git" -prune -exec rm -rf {} + && \
    find /usr/local/bundle -name ".github" -prune -exec rm -rf {} + && \
    find /usr/local/bundle -type d -name spec -prune -exec rm -rf {} + && \
    find /usr/local/bundle/bundler/gems/decidim-* -type d -name docs -prune -exec rm -rf {} + && \
    find /usr/local/bundle/bundler/gems/decidim-* -type d -name db -prune -exec rm -rf {} + && \
    find /usr/local/bundle -wholename "*/decidim-dev/lib/decidim/dev/assets/*" -exec rm -rf {} +

################################################################################

FROM ruby:3.3.11-slim

ENV RAILS_ENV=production \
    NODE_ENV=production \
    SECRET_KEY_BASE=dummy \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    LD_PRELOAD=libjemalloc.so.2 \
    MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:5000,muzzy_decay_ms:5000,narenas:2"

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      curl \
      imagemagick \
      postgresql-client \
      p7zip \
      libjemalloc2 && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 decidim && \
    useradd \
      --uid 1000 \
      --gid decidim \
      --create-home \
      --shell /bin/bash \
      decidim

WORKDIR /opt/decidim

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /opt/decidim /opt/decidim

RUN chown -R decidim:decidim /opt/decidim

USER decidim

EXPOSE 3000

HEALTHCHECK --interval=1m --timeout=5s --start-period=30s \
  CMD curl -fsS http://localhost:3000/up || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]