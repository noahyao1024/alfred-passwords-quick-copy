# Forum post draft

Post this in **Share your Workflows**: https://www.alfredforum.com/forum/3-share-your-workflows/

Add a screenshot and delete this header before posting. The download link below
is live.

---

**Title:** Passwords Quick Copy — verification codes, and why the Passwords app can't be scripted

---

This started as an attempt to copy passwords straight out of Apple's Passwords
app. That turned out to be impossible, so the workflow ships the part that does
work — verification codes — and documents the rest.

**Download:** https://github.com/noahyao1024/alfred-passwords-quick-copy/releases/latest

## Setup

Store a seed once per account. Seeds live in your login keychain, not in the
workflow:

```
python3 src/totp.py --store "you@example.com"
```

Requires macOS Sequoia or later. No Accessibility permission needed.

## Usage

Copy a time-based verification code for a stored account via the `otp` keyword.

* <kbd>↩</kbd> Copy the current code.

The clipboard clears after the delay set in the Workflow's Configuration, but
only if it still holds the copied value. Codes are generated locally (RFC 6238),
so it works offline and never opens the Passwords app. The implementation is
checked against the RFC's test vectors on every build, including non-default
digits, periods and algorithms.

## Why it doesn't read the Passwords app

Tested on macOS 26.6.1 against an unlocked app with 1,376 entries. Searching and
filtering can be driven fine. Selecting a result cannot, and every *Copy…*
command is gated on the app having a current item.

Nothing registers a selection: accessibility `selected`, arrow keys, `AXPress`,
or a synthetic click at the row's screen coordinates. The row context menu is
absent from the accessibility tree entirely. The menu bar *Edit → Copy Password*
item is readable but never becomes enabled. The app vends no Shortcuts actions
and is not AppleScript-scriptable.

Two traps if anyone wants to dig further:

- The window has more than one outline, and the first one found is the
  **sidebar**, not the results. Selecting its rows silently changes your search
  scope, including into shared groups.
- While locked the app reports **zero windows**, with authentication handled by
  a separate process, so an early `window 1` reference goes stale and everything
  afterwards fails with `-1719`.

The `pwdump` keyword saves a redacted accessibility tree to your Desktop if you
want to look yourself — roles and control names kept, anything that could hold
one of your entries replaced with a character count, so it's safe to post.

Everything is plain Python and shell, standard library only, no binaries, so
it's fully auditable. I'd be glad to be proved wrong about the Passwords app —
if someone finds a route to a selection, the copy side is written and waiting.
