#!/bin/bash
# Recode development environment entrypoint
set -euo pipefail

# Import GitHub GPG keys for user
gpg --import ~/.gnupg/recode_github_gpg_public.pgp
gpg --import ~/.gnupg/recode_github_gpg_private.pgp

# Run the CMD passed as command-line arguments
exec "$@"