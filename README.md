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

Early release. Run against macOS 26.6.1, where the following are confirmed
working: both scripts compile, the package builds, the workflow launches
Passwords and walks its accessibility tree, `pwdump` produces a correctly
redacted and readable dump, and every failure path exits within about 30
seconds with a message naming the actual problem.

**The copy action does not currently work on macOS 26.6.1.** This has now been
tested against an unlocked app with real entries, and the mechanism it is built
on is not there:

- `perform action "AXShowMenu"` on a result row produces no accessible menu.
  Not as a child of the row, not on the outline, not on the process, and not as
  a new window; a recursive search finds no `AXMenu` element at any depth. The
  workflow clicks *Copy Password* in exactly that menu, so the copy step fails.
- The results outline reports 5 rows for 1,376 entries, so its top-level rows
  are section headers rather than entries. The row-selection logic assumes
  entries.

Apple appears to render this context menu in a way that is not exposed to the
Accessibility API. Until there is another route to the *Copy…* commands, the
`pass` keyword will not copy anything. `pwdump` works and is useful for
investigating this.

Note that Passwords must be **unlocked** before the workflow can find anything.
While it is locked the app reports zero windows and authentication is handled
by a separate system process that the workflow cannot drive, so `pass` will
wait, then tell you to unlock and try again.

Please open an issue with your `pwdump` output and macOS version if something
does not resolve.

## Licence

MIT — see [LICENSE](LICENSE).
