default:
    @just --choose

endpoints:
    hurl --variables-file vars.env --test endpoints.hurl
