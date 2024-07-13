# Dotfiles

Various configuration files for my Linux-based systems.

The main goal of this is to make it easy for me to set up a new machine by just booting into the live installer (Arch, NixOS) and running this:

```bash
curl -L "https://arch-setup.viktors.net" -o setup.sh
# ... or nixos-setup.viktors.net
chmod u+x setup.sh
./setup.sh --user=alice --host=alpha --domain=example.com --drive=/dev/sdX
```

Et voilà, I'm back at home.

Hosting it publicly here makes it easy to:

* Point parts of `viktors.net` at it (long live `raw.githubusercontent.com`).
* Fetch individual dotfiles from work and other setups.
* Share it with others & seek feedback.

### Credits

> `wallpaper.jpg` was created by Eberhard Grossgasteiger and downloaded from
> [pexels.com](https://www.pexels.com) as
> [Free to use](https://www.pexels.com/license/).
