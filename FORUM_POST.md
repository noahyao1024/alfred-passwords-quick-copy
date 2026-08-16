# Forum post draft

Post this in **Share your Workflows**: https://www.alfredforum.com/forum/3-share-your-workflows/

Add a screenshot and delete this header before posting.

---

**Title:** Verification codes from Alfred, generated locally

---

Copies a time-based verification code to your clipboard. Codes are generated
locally from a seed held in your login keychain, so it works offline, opens
nothing, and needs no Accessibility permission.

**Download:** https://github.com/noahyao1024/alfred-verification-codes/releases/latest

## Setup

Store a seed, once per account:

```
python3 src/totp.py --store "you@example.com"
```

Either a bare base32 secret or a full `otpauth://` URI. A URI is preferable
where you have one, since it carries the digit count, period and algorithm.

Requires macOS Sequoia or later.

## Usage

* Type `otp`, pick the account, press <kbd>↩</kbd>.

The clipboard clears after the delay set in the Workflow's Configuration, but
only if it still holds the copied value — compared by SHA-256, so the code is
never held in a shell variable.

## Notes

The implementation is RFC 6238, checked against that document's published test
vectors on every build, including non-default digit counts, periods and hash
algorithms. Assuming the usual 6/30/SHA1 for an issuer that differs produces
codes that look perfectly plausible and never work, which is a miserable thing
to debug at a login prompt.

Standard library Python and shell only — no pip install, no third-party binary,
nothing to audit but two short files.

This started as an attempt to copy passwords straight out of Apple's Passwords
app, which turned out to be impossible. If you are curious why, the evidence is
written up in FINDINGS.md in the repository.
