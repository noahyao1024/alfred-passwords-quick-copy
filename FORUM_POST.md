# Forum post draft

Post this in **Share your Workflows**: https://www.alfredforum.com/forum/3-share-your-workflows/

Replace `YOUR-GITHUB-USERNAME` throughout, add screenshots, and delete this
header before posting.

---

**Title:** Passwords Quick Copy — copy from the Apple Passwords app

---

Apple's Passwords app has no scripting support, and because it is built on the
data protection keychain rather than the file-based one, the `security` CLI
cannot read its entries either — [Apple DTS confirmed as
much](https://developer.apple.com/forums/thread/807782). So this workflow goes
through the Accessibility API instead: it activates Passwords, searches, selects
the first match and clicks the appropriate *Copy…* item from the row's context
menu, then hides the app again.

**Download:** https://github.com/YOUR-GITHUB-USERNAME/alfred-passwords-quick-copy/releases/latest

## Setup

Grant Alfred Accessibility permission in System Settings → Privacy & Security →
Accessibility. Requires macOS Sequoia or later.

## Usage

Search your Apple Passwords entries and copy a field to the clipboard via the
`pass` keyword.

![Searching passwords](images/search.png)

* <kbd>↩</kbd> Copy the password.
* <kbd>⌘</kbd><kbd>↩</kbd> Copy the username.
* <kbd>⌥</kbd><kbd>↩</kbd> Copy the verification code.
* <kbd>⌃</kbd><kbd>↩</kbd> Copy the website.

The clipboard is cleared after the delay set in the Workflow's Configuration,
but only if it still holds the copied value — compared by hash, so the secret
is never held in a shell variable.

Alternatively, save the Passwords app's accessibility tree to your Desktop via
the `pwdump` keyword. The dump is redacted — roles and control names are kept,
anything that could hold one of your entries is replaced with a character
count — so it is safe to paste into a bug report.

## Notes and caveats

This is an early release and I would welcome testing, particularly on:

- **Non-English systems.** The context menu item names are matched as English
  strings (`Copy Password`, `Copy User Name`, `Copy Verification Code`,
  `Copy Website`). On a localised system these need changing — `pwdump` prints
  the correct ones.
- **Different macOS versions.** The scripts look elements up by role rather than
  hardcoding a path through the hierarchy, but Apple can restructure the UI at
  any point. Built and compile-checked on macOS 26.6.1.

Everything is plain AppleScript and shell, no binaries, so it is fully
auditable. Bug reports with `pwdump` output and a macOS version are especially
useful.
