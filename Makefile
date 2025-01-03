# Makefile - for edsh, exsh, vish, vimsh
# Copyright (c) 2025 Ian P Jarvis

INSTALL_DIR=/usr/local/bin

all:
    chmod +x eds.sh exs.sh vi.sh vim.sh
    cp eds.sh $INSTALL_DIR/edsh
    cp exs.sh $INSTALL_DIR/exsh
    cp vi.sh $INSTALL_DIR/vish
    cp vim.sh $INSTALL_DIR/vimsh
