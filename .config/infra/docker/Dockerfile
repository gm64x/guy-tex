# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e

# Only the TeX packages used by this project are installed in the build stage.
FROM debian:bookworm-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
       latexmk \
       lmodern \
       texlive-bibtex-extra \
       texlive-fonts-recommended \
       texlive-lang-portuguese \
       texlive-latex-extra \
       texlive-pictures \
       texlive-plain-generic \
       texlive-publishers \
       texlive-science

WORKDIR /src
COPY . .

ARG LATEX_ROOT=main.tex
ARG OUTPUT_NAME=main.pdf
ARG PDF_VERSION=7

RUN test "${LATEX_ROOT##*.}" = tex \
    && case "$OUTPUT_NAME" in */*) exit 2 ;; esac \
    && latexmk -pdf \
       -pdflatex="pdflatex %O \"\pdfminorversion=${PDF_VERSION}\input{%S}\"" \
       -interaction=nonstopmode -halt-on-error \
       -outdir=/out "$LATEX_ROOT" \
    && source_name="$(basename "${LATEX_ROOT%.tex}").pdf" \
    && test -s "/out/$source_name" \
    && mkdir /artifact \
    && cp "/out/$source_name" "/artifact/$OUTPUT_NAME"

# Stage 2: the deliverable image contains only the compiled PDF.
FROM scratch AS artifact
COPY --from=builder /artifact/ /
