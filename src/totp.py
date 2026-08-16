#!/usr/bin/env python3
"""Generate TOTP codes (RFC 6238) from secrets held in the macOS keychain.

    totp.py <account>             print the current code
    totp.py --store <account>     read a secret or otpauth:// URI from stdin
    totp.py --list                list stored accounts
    totp.py --remove <account>    forget an account
    totp.py --selftest            check against the RFC 6238 test vectors

Standard library only: no pip install, no third-party binary. That keeps the
workflow installable by double-click, which the Alfred Gallery requires.

Secrets live in the login keychain. Account *names* are kept in a plain index
file so that listing them does not require dumping the keychain, which would
throw an authorisation prompt every time Alfred drew a list. The index holds
names only, never secrets.
"""

import base64
import hashlib
import hmac
import json
import os
import struct
import subprocess
import sys
import time
import urllib.parse

# These two name where your seeds are stored, so they are deliberately frozen
# even though the workflow has since been renamed. Changing either would hide
# every seed already in the keychain, which is a data loss dressed up as a
# cosmetic tidy-up. They are internal identifiers; nothing shows them to users.
SERVICE = "alfred-passwords-quick-copy-totp"
INDEX = os.path.expanduser(
    "~/Library/Application Support/alfred-passwords-quick-copy/accounts.json"
)

ALGORITHMS = {
    "SHA1": hashlib.sha1,
    "SHA256": hashlib.sha256,
    "SHA512": hashlib.sha512,
}


# --------------------------------------------------------------------------
# the algorithm

def generate(secret_b32, when=None, digits=6, period=30, digest=hashlib.sha1):
    """The RFC 6238 construction: HOTP over the number of elapsed periods."""
    # Base32 secrets are commonly stored unpadded, lowercased, or spaced.
    s = secret_b32.strip().replace(" ", "").replace("-", "").upper()
    s += "=" * (-len(s) % 8)
    key = base64.b32decode(s, casefold=True)

    counter = int((time.time() if when is None else when) // period)
    mac = hmac.new(key, struct.pack(">Q", counter), digest).digest()

    # Dynamic truncation (RFC 4226 5.3): the low nibble of the last byte
    # picks the 4-byte window, and the top bit is masked off.
    offset = mac[-1] & 0x0F
    code = struct.unpack(">I", mac[offset:offset + 4])[0] & 0x7FFFFFFF
    return str(code % (10 ** digits)).zfill(digits)


def parse_uri(uri):
    """Pull the parameters out of an otpauth:// URI.

    Issuers do use non-default values -- 8 digits, 60-second periods, SHA256 --
    and assuming 6/30/SHA1 for those produces codes that look plausible and are
    always wrong, so the URI's own parameters win where present.
    """
    parts = urllib.parse.urlparse(uri)
    if parts.scheme != "otpauth":
        raise ValueError("not an otpauth:// URI")
    if parts.netloc.lower() != "totp":
        raise ValueError(f"unsupported OTP type: {parts.netloc!r} (only totp)")

    q = urllib.parse.parse_qs(parts.query)
    if "secret" not in q:
        raise ValueError("URI has no secret parameter")

    algo = q.get("algorithm", ["SHA1"])[0].upper()
    if algo not in ALGORITHMS:
        raise ValueError(f"unsupported algorithm: {algo}")

    return {
        "secret": q["secret"][0],
        "digits": int(q.get("digits", ["6"])[0]),
        "period": int(q.get("period", ["30"])[0]),
        "algorithm": algo,
        "label": urllib.parse.unquote(parts.path.lstrip("/")),
    }


def derive_name(secret):
    """Best account name for a seed, so Alfred can add one without being told.

    otpauth labels are conventionally "Issuer:account", and the account half is
    what someone would actually search for.
    """
    if not secret.strip().lower().startswith("otpauth://"):
        return ""
    label = parse_uri(secret.strip())["label"]
    if ":" in label:
        return label.split(":", 1)[1].strip()
    return label.strip()


def code_for(stored, when=None):
    """Stored value is either an otpauth:// URI or a bare base32 secret."""
    if stored.strip().lower().startswith("otpauth://"):
        p = parse_uri(stored.strip())
        return generate(p["secret"], when=when, digits=p["digits"],
                        period=p["period"], digest=ALGORITHMS[p["algorithm"]])
    return generate(stored, when=when)


def seconds_remaining(stored):
    period = 30
    if stored.strip().lower().startswith("otpauth://"):
        try:
            period = parse_uri(stored.strip())["period"]
        except ValueError:
            pass
    return period - int(time.time()) % period


# --------------------------------------------------------------------------
# storage

def index_load():
    try:
        with open(INDEX) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def index_save(names):
    os.makedirs(os.path.dirname(INDEX), exist_ok=True)
    with open(INDEX, "w") as f:
        json.dump(sorted(set(names)), f, indent=2)


def store(account, secret):
    secret = secret.strip()
    if not secret:
        raise ValueError("empty secret")
    code_for(secret)  # validate now, so a typo fails here and not at 3am
    subprocess.run(
        ["security", "add-generic-password", "-U",
         "-s", SERVICE, "-a", account, "-w", secret],
        check=True, capture_output=True,
    )
    index_save(index_load() + [account])


def load(account):
    r = subprocess.run(
        ["security", "find-generic-password", "-s", SERVICE, "-a", account, "-w"],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit(f"No secret stored for {account!r}. Add one with --store.")
    return r.stdout.strip()


def remove(account):
    subprocess.run(
        ["security", "delete-generic-password", "-s", SERVICE, "-a", account],
        capture_output=True,
    )
    index_save([n for n in index_load() if n != account])
    print(f"Removed {account}.")


# --------------------------------------------------------------------------
# commands

def cmd_list():
    names = index_load()
    if not names:
        print("No accounts stored yet. Add one with --store.")
    for n in names:
        print(n)


def cmd_alfred():
    """Script Filter JSON for Alfred: the list of accounts, no secrets."""
    names = index_load()
    if not names:
        items = [{
            "title": "No verification codes stored",
            "subtitle": "Copy a secret or otpauth:// link, then use the otpadd keyword",
            "valid": False,
        }]
    else:
        items = [{
            "title": n,
            "subtitle": "↩ copy the current code    ⌥↩ forget this account",
            "arg": n,
            "match": n,
        } for n in names]
    print(json.dumps({"items": items}))


def selftest():
    """RFC 6238 Appendix B (SHA-1 rows), plus URI parsing."""
    ok = True
    secret = base64.b32encode(b"12345678901234567890").decode()
    for when, expected in [
        (59, "94287082"), (1111111109, "07081804"), (1111111111, "14050471"),
        (1234567890, "89005924"), (2000000000, "69279037"),
        (20000000000, "65353130"),
    ]:
        got = generate(secret, when=when, digits=8)
        ok &= got == expected
        print(f"  RFC T={when:<12} expected={expected} got={got}"
              f"  {'ok' if got == expected else 'FAIL'}")

    # A URI with non-default parameters must be honoured, not assumed.
    uri = (f"otpauth://totp/Example:alice@example.com?secret={secret}"
           f"&digits=8&period=30&algorithm=SHA1&issuer=Example")
    p = parse_uri(uri)
    checks = [
        ("digits", p["digits"], 8),
        ("period", p["period"], 30),
        ("algorithm", p["algorithm"], "SHA1"),
        ("label", p["label"], "Example:alice@example.com"),
        ("code", code_for(uri, when=59), "94287082"),
    ]
    for name, got, want in checks:
        ok &= got == want
        print(f"  URI {name:<10} expected={want} got={got}"
              f"  {'ok' if got == want else 'FAIL'}")

    # A bare base32 secret must still work, for hand-entered secrets.
    bare = code_for(secret, when=1111111109)
    ok &= bare == "081804"
    print(f"  bare secret  expected=081804 got={bare}"
          f"  {'ok' if bare == '081804' else 'FAIL'}")

    print("selftest passed" if ok else "SELFTEST FAILED")
    return 0 if ok else 1


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)

    cmd = args[0]
    if cmd == "--selftest":
        sys.exit(selftest())
    if cmd == "--list":
        return cmd_list()
    if cmd == "--alfred":
        return cmd_alfred()
    if cmd == "--remove":
        if len(args) < 2:
            sys.exit("Usage: totp.py --remove <account>")
        return remove(args[1])
    if cmd == "--store":
        secret = sys.stdin.read()
        # The account name is optional: an otpauth:// link already carries one,
        # which is what lets the Alfred side add a seed with no typing at all.
        account = args[1] if len(args) > 1 else ""
        if not account:
            try:
                account = derive_name(secret)
            except ValueError as exc:
                sys.exit(f"That does not look like a TOTP secret: {exc}")
            if not account:
                sys.exit("Give an account name: a bare secret carries none.")
        try:
            store(account, secret)
        except ValueError as exc:
            sys.exit(f"That does not look like a TOTP secret: {exc}")
        print(f"Stored {account}")
        return

    print(code_for(load(cmd)))


if __name__ == "__main__":
    main()
