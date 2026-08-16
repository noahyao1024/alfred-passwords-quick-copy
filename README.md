# Passwords Quick Copy

An [Alfred](https://www.alfredapp.com) workflow that copies time-based
verification codes to the clipboard, generated locally from seeds held in your
login keychain.

## Setup

Store a seed, once per account:

```sh
python3 src/totp.py --store "you@example.com"   # paste the secret, then Ctrl-D
```

Seeds live in the login keychain, never in this workflow or this repository.

Requires macOS Sequoia or later. No Accessibility permission is needed.

## Usage

Copy a time-based verification code for a stored account via the `otp` keyword.

* <kbd>↩</kbd> Copy the current code.

The clipboard is cleared after the delay set in the Workflow's Configuration,
but only if it still holds the copied value — compared by SHA-256, so the code
is never held in a shell variable.

Codes are generated locally, so this works offline and never opens the Passwords
app. The implementation is
[RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238), checked against that
document's published test vectors on every build, including non-default digit
counts, periods and hash algorithms.

## Managing seeds

```sh
python3 src/totp.py --store "you@example.com"   # add or replace one
python3 src/totp.py --list                      # stored accounts
python3 src/totp.py --remove "you@example.com"  # forget one
python3 src/totp.py --selftest                  # RFC 6238 vectors
```

Seeds may be given either as a bare base32 secret or as a full `otpauth://` URI.
A URI is preferable where you have one: it carries the digit count, period and
algorithm, and those are honoured rather than assumed. Assuming the usual
6/30/SHA1 for an issuer that differs produces codes that look perfectly
plausible and never work.

## Security notes

Storing a seed outside your password manager means a second copy of your second
factor exists. If it sits on the same machine as the password it protects, the
two factors collapse into one device. That is true of any authenticator app on
your laptop, but it is worth deciding deliberately rather than by accident.

If an account belongs to an employer, check their security policy before moving
its seed into a personal tool.

## Development

```
src/     workflow source (info.plist, scripts, icon)
dist/    built .alfredworkflow package
```

```sh
./build.sh              # runs the TOTP selftest, then packages
python3 build_plist.py  # regenerate info.plist only
```

The build fails if the RFC 6238 vectors stop matching. That guard exists because
this shipped once with a generator that had never been verified.

## Prior history

This workflow started out trying to copy passwords directly from Apple's
Passwords app. That turned out to be impossible; the evidence is written up in
[FINDINGS.md](FINDINGS.md), and the code that attempted it is in the git
history.

## Licence

MIT — see [LICENSE](LICENSE).
