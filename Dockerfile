# Audiobookshelf for Railway.
#
# Audiobookshelf (advplyr/audiobookshelf, GPL-3.0) is a self-hosted audiobook and podcast server. The upstream image is
# unchanged. This wrapper adds what an agent-driven public Railway deploy needs:
#
# 1. A fresh server answers `POST /init` from anyone until a root user exists, so whoever reaches the new domain first
#    owns the library. The boot script creates the root user from ADMIN_PASSWORD while the server is bound to
#    127.0.0.1 only, then starts the public listener.
# 2. It also creates the two libraries (Audiobooks, Podcasts) so a client has somewhere to write on first contact.
# 3. Railway allows one volume per service, so config, metadata and both library folders live under /data.
#
# upstream: advplyr/audiobookshelf
FROM ghcr.io/advplyr/audiobookshelf:2.37.2@sha256:b897c33f05972fb1bf484f7487bc878fa91ec8691335c1db6e2929c3a7658efa

ENV CONFIG_PATH=/data/config \
    METADATA_PATH=/data/metadata

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["tini", "--", "/usr/local/bin/railway-entrypoint.sh"]
CMD ["node", "dist-server/index.js"]

EXPOSE 8080
