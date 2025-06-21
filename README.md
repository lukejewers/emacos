# emacos.el - Control macOS from Emacs

Control macOS applications and system functions directly from Emacs.

## Commands

| Command | Action |
| :--- | :--- |
| `emacos-open-app` | Launch installed applications via `open -a` |
| `emacos-close-app` | Quit running applications |
| `emacos-open-file-in-firefox` | Open selected file in Firefox |
| `emacos-open-file-in-chrome` | Open selected file in Google Chrome |
| `emacos-reveal-file-at-point-in-finder` | Open file at point in Finder |
| `emacos-reveal-in-finder` | Open selected file in Finder with completion |
| `emacos-open-trash` | Open Trash folder in Finder |
| `emacos-empty-trash` | Permanently delete all items in Trash |
| `emacos-get-file-path` | Copy absolute path of current file to kill ring |
| `emacos-toggle-menu-bar` | Toggle visibility of the macOS menu bar |
| `emacos-toggle-dock` | Toggle auto-hide behavior of the macOS dock |
| `emacos-sleep-display` | Put display to sleep immediately |

## Installation

### Use package

```elisp
(use-package emacos
  :if (eq system-type 'darwin)
  :vc (:url "https://github.com/lukejewers/emacos.git"
       :rev :newest))
```

### Manual Installation

1. Clone or download this repository
2. Add to your Emacs config:

```elisp
(add-to-list 'load-path "/path/to/emacos-directory")
(require 'emacos)
```
Or
```elisp
(use-package emacos
  :load-path "/path/to/emacos-directory")
```
