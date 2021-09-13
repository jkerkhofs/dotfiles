# WSL setup

## Update

```bash
sudo apt update
sudo apt upgrade
```

## Dotfiles

- Clone the dotfiles repo

  ```bash
  git clone https://github.com/jkerkhofs/dotfiles.git
  ```

- Install the dotfiles

  ```bash
  ./install
  ```

## Shell

- Install zsh

  ```bash
  sudo apt install zsh
  ```

- Change the default shell to zsh

  ```bash
  chsh -s /bin/zsh
  ```

## Basic dependencies

- Install the build essentials

  ```bash
  sudo apt install build-essential
  ```

- Install zip packages

  ```bash
  sudo apt install zip unzip
  ```

## NVM & Node

- Install nvm (replace version number with latest version)

  ```bash
  mkdir ~/.nvm
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
  ```

- Install node

  ```bash
  nvm install --lts
  ```

- Set default node version

  ```bash
  nvm alias default stable
  ```

## Neovim dependencies

- Install neovim node package

  ```bash
  npm install -g neovim
  ```

- Install python2

  ```bash
  sudo apt install python2
  curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
  sudo python2 get-pip.py
  rm get-pip.py
  python2 -m pip install --user --upgrade pynvim
  ```

- Install python3

  ```bash
  sudo apt install python3-pip
  python3 -m pip install --user --upgrade pynvim
  ```

## Neovim

- Install the neovim appimage

  ```bash
  cd ~
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
  chmod u+x nvim.appimage
  sudo mv nvim.appimage /usr/local/bin/nvim
  ```

- Setup neovim clipboard support

  ```bash
  curl -LO https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip
  unzip -p win32yank-x64.zip win32yank.exe > win32yank.exe
  chmod u+x win32yank.exe
  sudo mv win32yank.exe /usr/local/bin
  rm win32yank-x64.zip
  ```

## Tmux

- Add symlink for tmux (needed for older versions of tmux that don't use XDG rules)

  ```bash
  ln -s .dotfiles/tmux/tmux.conf .tmux.conf
  ```

- Install tmux plugins

  ```bash
   ~/.config/tmux/plugins/tpm/bin/install_plugins
  ```

## Lazygit

Note: check the version number for the latest version.

```bash
curl -LO https://github.com/jesseduffield/lazygit/releases/download/v0.29/lazygit_0.29_Linux_x86_64.tar.gz
tar xvf lazygit_0.29_Linux_x86_64.tar.gz lazygit
rm lazygit_0.29_Linux_x86_64.tar.gz
sudo mv lazygit /usr/local/bin
```
