FROM archlinux AS builder

RUN pacman -Syu --noconfirm --needed \
      base-devel \
      git

RUN useradd -m builder \
 && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER builder

RUN git clone https://aur.archlinux.org/globalprotect-openconnect-git.git \
      && cd globalprotect-openconnect-git \
      && makepkg -si --noconfirm

FROM archlinux

# # COPY --from=builder /*.zst .
COPY pkgs/*.zst .

RUN pacman -Syu --noconfirm \
 && pacman -U --noconfirm /*.zst \
 && pacman -S --noconfirm  sudo vim  \
 && rm -f /*.zst \
 && rm -rf /var/cache/pacman/pkg
