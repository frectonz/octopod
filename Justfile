default:
    @just --choose

api:
    hurl --variables-file vars.env --test api.hurl

run:
    cd ui; elm make src/Main.elm --debug --output Main.js
    cargo run -- --registry-url hello

fmt:
    cd ui; elm-format . --yes
    cargo fmt
    nix fmt
