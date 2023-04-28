schemas:
  mkdir -p webui/schemas
  nix eval --json .#erigon > webui/schemas/erigon.json
