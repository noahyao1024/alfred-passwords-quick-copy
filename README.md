# Passwords Quick Copy

An [Alfred](https://www.alfredapp.com) workflow for verification codes, plus a
documented investigation into why copying directly from the Apple **Passwords**
app is not possible.

## Setup

Store a seed once per account. Seeds live in your login keychain, never in this
workflow:

```sh
python3 src/totp.py --store "you@example.com"   # paste the secret, then Ctrl-D
```

If you have a Passwords app export to hand, the seeds can be pulled out of it
instead:

```sh
python3 src/totp.py --import ~/Desktop/Passwords.csv
rm -P ~/Desktop/Passwords.csv                   # it holds cleartext passwords
```

Requires macOS Sequoia or later. No Accessibility permission is needed for the
`otp` keyword.

## Usage

Copy a time-based verification code for a stored account via the `otp` keyword.

* <kbd>↩</kbd> Copy the current code.

The clipboard is cleared after the delay set in the Workflow's Configuration,
but only if it still holds the copied value — compared by SHA-256, so the code
is never held in a shell variable.

Codes are generated locally from the stored seed, so this works offline and
never opens the Passwords app. The implementation is
[RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238) and is checked
against that document's published test vectors on every build, including
non-default digit counts, periods and hash algorithms.

Other commands:

```sh
python3 src/totp.py --list             # stored accounts
python3 src/totp.py --remove <account> # forget one
python3 src/totp.py --selftest         # RFC 6238 vectors
```

## Copying from the Passwords app does not work

This is what the workflow was originally for, and it cannot be made to work.
The `pass` keyword is left in place for anyone who wants to investigate
further, but it does not copy anything. Recorded here so the next person does
not spend a day rediscovering it.

Tested on macOS 26.6.1 against an unlocked app with 1,376 entries.

**What works.** Launching the app, waiting through the unlock, typing into the
search field, and the results filtering — confirmed by the window title
reporting the match count.

**What does not.** Selecting a result. Every *Copy…* command in the app is
gated on it having a current item, and nothing makes it register one:

| Approach | Result |
| --- | --- |
| `set selected of row to true` | Copy commands stay disabled |
| Arrow-key navigation from the search field | disabled |
| `perform action "AXPress"` on the row | disabled |
| Synthetic click at the row's screen coordinates | disabled |
| Row context menu via `AXShowMenu` | No menu exists anywhere in the accessibility tree |
| Menu bar *Edit* → *Copy Password* | Present and readable, never becomes enabled |
| Shortcuts / App Intents | The app vends none |
| AppleScript dictionary | The app is not scriptable |
| `security` CLI | Data protection keychain has no command-line access |

Two things worth knowing if you pick this up:

- The window contains more than one outline. The first one found is the
  **sidebar** (All, Passkeys, Codes, Wi-Fi…), not the results. Selecting its
  rows changes the search scope rather than picking an entry, and will silently
  switch you into a shared group.
- While locked, the app reports **zero windows** and authentication is handled
  by a separate process, so a `window 1` reference captured early goes stale and
  every later lookup fails with `-1719`.

`pwdump` still works and saves a redacted accessibility tree to your Desktop:
roles, subroles and control names are kept, while anything that could hold one
of your entries is replaced with a character count, so the output is safe to
attach to a public issue. Passing `full` as a second argument disables
redaction; that output contains your account names.

Apple's Developer Technical Support has
[confirmed](https://developer.apple.com/forums/thread/807782) there is no
command-line access to the data protection keychain, which is why
`security find-internet-password` cannot see these entries either. The nearest
prior art, [alfred-icloud-passwords](https://github.com/leolabs/alfred-icloud-passwords),
drives the old System Preferences pane rather than the standalone app, and has
been unmaintained since 2023.

## Security notes

Storing a seed outside the Passwords app means a second copy of your second
factor exists. If it sits on the same machine as the password it protects, the
two factors collapse into one device. That is true of any authenticator app on
your laptop, but it is worth deciding deliberately rather than by accident.

Exporting from Passwords writes credentials to disk in cleartext. Prefer
*Export Selected Passwords to File…* over *Export All*, and remove the file
afterwards with `rm -P`.

If the account belongs to an employer, check their security policy before
moving its seed into a personal tool.

## Development

```
src/     workflow source (info.plist, scripts, icon)
dist/    built .alfredworkflow package
```

```sh
./build.sh              # compiles the AppleScripts, runs the TOTP selftest, packages
python3 build_plist.py  # regenerate info.plist only
```

The build fails if either AppleScript stops compiling or the TOTP vectors stop
matching. Both checks exist because both classes of bug shipped here once: a
script that had never been compiled, and a generator that had never been
verified.

## Licence

MIT — see [LICENSE](LICENSE).
