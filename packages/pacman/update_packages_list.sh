printf '%s\n' '# Inventory only; packages/aur.txt controls installer AUR input.' > arch-aur-packages.txt
pacman -Qqem >> arch-aur-packages.txt
pacman -Qqen > arch-official-packages.txt
