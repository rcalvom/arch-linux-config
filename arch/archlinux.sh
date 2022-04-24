# Cambiar layout de teclado.
loadkeys la-latin1

# Configuración de WiFi
iwctl
station list
station <wlan> scan
station <wlan> get-networks
station <wlan> connect <SSID>
exit

# Probar internet
ping google.com

# Configuración Lectura de Fecha y Hora
timedatectl set-ntp true

# Mirrors
pacman -S reflector
reflector -c Colombia -a 6 --sort rate --save /etc/pacman.d/mirrorlist

# Borrar Tabla de particiones disco duro
wipefs -a /dev/sda

# Crear tabla de partición
sgdisk -Z /dev/sda

# Crear particiones
cfdisk
## 550MB: Arranque (EFI System)
## 5G: SWAP (Linux Swap)
## restante: Sistema de archivos (Linux filesystem)

# Formatear a FAT32 la particion de arranque
mkfs.fat -F32 /dev/sda1

# Formatear particion de intercambio
mkswap /dev/sda2

# Activar memoria de intercambio
swapon /dev/sda2

# Formatear a EXT4 la particion de archivos
mkfs.ext4 /dev/sda3

# Montar particion de archivos
mount /dev/sda3 /mnt

# Crear carpeta para particion de arranque
mkdir /mnt/boot

# Montar particion de arranque
mount /dev/sda1 /mnt/boot

# Instalar paquetes escenciales Linux
pacstrap /mnt base linux linux-firmware sudo nano
# Wait

# Generar archivo fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Definir ruta raiz
arch-chroot /mnt

# Establecer zona horaria
ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime

# Establecer Hora
hwclock --systohc

# Definir locales
nano /etc/locale.gen

# Generar locales
locale-gen
#en_US.UTF-8 UTF-8

# Definir idioma, Escribir: LANG=en_US.UTF-8
nano /etc/locale.conf 

# Definir layout vconsole, Escribir: KEYMAP=la-latin1
nano /etc/vconsole.conf

# Definir hostname, Escribir: Archlinux
nano /etc/hostname

# Definir ip para mapear
# Escribir: 
# 127.0.0.1     localhost
# ::1           localhost
# 127.0.0.1     Archlinux.localdomain Archlinux
nano /etc/hosts

# Instalar network manager
pacman -S networkmanager ntfs-3g grub efibootmgr os-prober base-devel linux-headers bluez bluez-utils pulseaudio-bluetooth xdg-utils xdg-user-dirs git

# Habilitar network manager
systemctl enable NetworkManager

# Colocar contraseña a root
passwd

# Instalar GRUB
grub-install --target=x86_64-efi --efi-directory=/boot

# Crear archivo de configuracion para GRUB
os-prober
grub-mkconfig -o /boot/grub/grub.cfg

# Crear usuario
useradd -m username
passwd username
usermod -aG wheel,video,audio,storage username

# Habilitar nano para usuario
nano /etc/sudoers

# Reiniciar
exit
umount -R /mnt
reboot

# Configurar WIFI
sudo nmcli device wifi list
sudo nmcli device wifi connect <SSID> password <YOUR_PASSWORD>

# Instalar XORG
sudo pacman -S xorg

# Instalar fuente
yay -S nerd-fonts-ubuntu-mono

# Instalar inicio de sesión
sudo pacman -S lightdm lightdm-gtk-greeter

# Instalar Qtile
#sudo pacman -S spectrwm trayer upower pamixer brightnessctl pacman-contrib
sudo pacman -S qtile

# Instalar visual studio code REEMPLAZAR POR YAY
#sudo pacman -S code

# Instalar firefox
sudo pacman -S firefox

# Habilitar Inicio de sesión
sudo systemctl enable lightdm
reboot

# Instalar alarcritty
sudo pacman -S alacritty

# Instalar rofi
sudo pacman -S rofi

# Configurar tema de rofi
sudo pacman -S which
rofi-theme-selector

# Configurar comandos al arranque
sudo pacman -S xorg-xinit
touch ~/.xprofile
nano ~/.xprofile

# Editar configuración de qtile
code ~/.config/qtile/config.py

# Wallpaper
sudo pacman -S feh
feh --bg-scale path/to/wallpaper

# Audio
sudo pacman -S pulseaudio pavucontrol
#TODO

# Brillo de pantalla
sudo pacman -S brightnessctl

sudo pacman -S redshift

# yay
cd /opt
sudo git clone https://aur.archlinux.org/yay-git.git
sudo chown -R tecmint:tecmint ./yay-git
cd yay-git
makepkg -si


yay -S lightdm-webkit-theme-aether

