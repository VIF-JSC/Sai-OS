# Remote desktop (xrdp) session: Cinnamon in software-rendering mode, since a
# cloud VM has no GPU. The local console keeps using LightDM as usual.
export XDG_SESSION_DESKTOP=cinnamon
export XDG_CURRENT_DESKTOP=X-Cinnamon
exec cinnamon-session-cinnamon2d
