# Reproducible demo image.
# On-brand: built on a Chainguard base image (minimal, low/zero-CVE).
# Both the "upstream" and "chainguard" jobs build THIS exact Dockerfile,
# so a successful, identical build proves the actions are drop-in equivalent.
FROM cgr.dev/chainguard/nginx:latest

# The only thing we add is a static page we control.
COPY app/index.html /usr/share/nginx/html/index.html
