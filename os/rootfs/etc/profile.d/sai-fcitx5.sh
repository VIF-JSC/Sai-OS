# Environment variables so every toolkit (GTK/Qt/SDL) talks to fcitx5.
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx
# GLFW keeps ibus as recommended by Lotus (compatibility with older game/Electron apps)
export GLFW_IM_MODULE=ibus
