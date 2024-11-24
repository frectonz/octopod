default:
    @just --choose

api:
    hurl --variables-file vars.env --test api.hurl

api-proxy:
    hurl --variable address=http://localhost:3030/api --test local.hurl

run:
    cd ui; elm make src/Main.elm --debug --output Main.js
    cargo run

dev:
    watchexec -r just run

fmt:
    cd ui; elm-format . --yes
    cargo fmt
    nix fmt
