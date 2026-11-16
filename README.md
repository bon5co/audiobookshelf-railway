# audiobookshelf-railway

Wrapper for the Railway template "Audiobookshelf". Keeps the upstream `ghcr.io/advplyr/audiobookshelf` image (pinned by digest) and adds a boot script that creates the root user from `ADMIN_PASSWORD` while the server listens on 127.0.0.1 only, creates the Audiobooks and Podcasts libraries on the `/data` volume, then starts the public listener on Railway's `PORT`. Upstream: https://github.com/advplyr/audiobookshelf (GPL-3.0).
