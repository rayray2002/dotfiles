#!/bin/bash

# cargo
curl https://sh.rustup.rs -sSf | sh

# eza
cargo install eza

# nvim
sudo apt-get install -y neovim

# bat
sudo apt-get install -y bat

# zoxide
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

#conda
wget https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh
bash Anaconda3-2024.10-1-Linux-x86_64.sh
