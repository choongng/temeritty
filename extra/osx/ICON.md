# The Temeritty icon

The icon is a photograph of a DEC VT100 terminal, from Chapter 1 of the
*VT100 User Guide*, as scanned and published by vt100.net:

- Photo: <https://vt100.net/docs/vt100-ug/vt100-photo.200dpi.jpg>
- Source: <https://vt100.net/docs/vt100-ug/chapter1.html>

`temeritty-icon.png` is the photo cut from its white background, placed on
the 1024 px macOS icon grid with a soft shadow.

`Temeritty.app/Contents/Resources/temeritty.icns` holds it at 16 to 1024 px.
To rebuild that, make an iconset of the PNG with `sips` (each of 16, 32, 128,
256 and 512 px, at 1x and 2x) and run `iconutil -c icns` on it.
