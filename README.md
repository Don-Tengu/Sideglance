# Sideglance

Sideglance gives your webcam a small, resizable window that can float above your work. Customize the border and window title from the macOS menu bar. The camera preview stays on your Mac.

## Install on macOS

Requires **macOS 14 or later**. The same download works on Apple silicon and Intel Macs.

1. [Download Sideglance for Mac](https://github.com/Don-Tengu/Sideglance/releases/latest/download/Sideglance.zip).
2. Unzip `Sideglance.zip` and drag `Sideglance.app` into **Applications**.
3. Open Sideglance, click **Enable Camera**, and grant camera access when macOS asks.

The release is ad-hoc signed and hasn’t been notarized by Apple. macOS may show a first-launch warning. [Apple’s guide to opening downloaded apps](https://support.apple.com/en-us/102445)

## Use the preview

- Drag the title bar to move the preview. Drag an edge or corner to resize it.
- Choose **View → Keep on Top** or press **⌘T**. The window starts pinned.
- Choose **View → Border Settings…** or press **⌘,** to change the border’s color, width, and corner radius. Pick a swatch or enter a six-digit hex color. Set width to zero to hide the border.
- Choose **View → Rename Preview…** to change the title shown on the preview window. Leave the name blank to hide it.
- Use the **Camera** menu to switch among available cameras. **Mirror Preview** is in the border panel and the **View** menu.
- Closing, minimizing, or hiding the preview stops camera capture. Press **⌘1** or click the Dock icon to reopen it.

Sideglance remembers your window title, position, size, and preferences.

## Build from source

With Xcode or the Xcode Command Line Tools installed, run this from the repo directory.

```sh
bash build.sh
open build/Sideglance.app
```

## License

[MIT](LICENSE)
