# Passwords Quick Copy

An [Alfred](https://www.alfredapp.com) workflow to copy a password, username,
verification code or website from the Apple **Passwords** app.

## Setup

Grant Alfred Accessibility permission in System Settings → Privacy & Security
→ Accessibility. Requires macOS Sequoia or later and an Alfred Powerpack
licence.

## Usage

Search your Apple Passwords entries and copy a field to the clipboard via the
`pass` keyword.

![Searching passwords](images/search.png)

* <kbd>↩</kbd> Copy the password.
* <kbd>⌘</kbd><kbd>↩</kbd> Copy the username.
* <kbd>⌥</kbd><kbd>↩</kbd> Copy the verification code.
* <kbd>⌃</kbd><kbd>↩</kbd> Copy the website.

The clipboard is cleared after the delay set in the Workflow’s Configuration,
but only if it still holds the copied value — compared by SHA-256, so the secret
is never held in a shell variable.

Alternatively, save the Passwords app’s accessibility tree to your Desktop via
the `pwdump` keyword. Use it if a field cannot be found.

The dump is redacted by default: element roles, subroles and the names of
interface controls are kept, but anything that could hold one of your entries —
static text, text fields, table rows — is replaced with a character count. That
is enough to debug a selector, and safe to attach to a public issue. Running
`osascript pw-dump.applescript "query" full` from the workflow folder disables
redaction; that output contains your account names, so keep it to yourself.

## Why this uses UI automation

There is no API for the Passwords app. It is built on the *data protection
keychain*, not the older file-based keychain that the `security` command-line
tool talks to. Apple's Developer Technical Support has
[confirmed](https://developer.apple.com/forums/thread/807782) that there is no
command-line access to the data protection keychain, which is why
`security find-internet-password` cannot see entries that appear in the
Passwords app.

That leaves the Accessibility API as the only route. The workflow activates
Passwords, types the query into the search field, selects the first result and
clicks the relevant *Copy…* item from the row's context menu.

The practical consequences:

- Alfred needs Accessibility permission, which is a broad grant.
- The Passwords app briefly takes focus, then hides itself again.
- Apple can change the app's UI in any macOS release and break this. The scripts
  search for elements by role rather than hardcoding paths, which helps, but
  does not make it immune.
- Context menu item names are localised. On a non-English system the strings
  matched in `pw-copy.applescript` need adjusting; `pwdump` shows the correct
  ones.

## Development

```
src/     workflow source (info.plist, scripts, icon)
dist/    built .alfredworkflow package
```

Build the package:

```sh
./build.sh
```

Regenerate `info.plist` after editing `build_plist.py`:

```sh
python3 build_plist.py
```

## Status

Early release. Both scripts compile, the package builds, and `build.sh` fails
the build if either script stops compiling. What has *not* been confirmed is
the part only a real machine with real entries can answer: whether the
accessibility tree of the Passwords app looks the way these scripts assume.
The element lookups are written defensively — by role rather than by a
hardcoded path — but they are assumptions until someone runs them.

Please open an issue with your `pwdump` output and macOS version if something
does not resolve.

## Licence

MIT — see [LICENSE](LICENSE).
