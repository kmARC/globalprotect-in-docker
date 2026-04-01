FROM archlinux AS builder

RUN pacman -Syu --noconfirm --needed \
      base-devel \
      git

RUN useradd -m builder \
 && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER builder

RUN git clone https://aur.archlinux.org/globalprotect-openconnect-git.git /tmp/globalprotect-openconnect-git

WORKDIR /tmp/globalprotect-openconnect-git

RUN makepkg -si --noconfirm

FROM archlinux

COPY --from=builder /tmp/globalprotect-openconnect-git/*.zst /tmp/

RUN pacman -Syu --noconfirm \
 && pacman -U --noconfirm /tmp/*.zst \
 && pacman -S --noconfirm sudo dbus chromium inetutils bind \
 && rm -rf /tmp/* \
 && rm -rf /var/cache/pacman/pkg
