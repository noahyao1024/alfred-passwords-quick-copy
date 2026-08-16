import plistlib, os

HERE = os.path.dirname(os.path.abspath(__file__))

# Set these before publishing. GH_USER is used for the bundle ID, which must be
# unique and is conventionally reverse-domain based on the author.
GH_USER = os.environ.get("GH_USER", "YOUR-GITHUB-USERNAME")
AUTHOR = os.environ.get("AUTHOR", "Your Name")
REPO = os.environ.get("REPO", "alfred-passwords-quick-copy")
# Must track the release tag: Alfred shows this and uses it for update checks,
# so a bundle claiming one version inside a differently tagged release is a
# real mismatch.
VERSION = os.environ.get("VERSION", "0.3.0")
SRC = os.path.join(HERE, "src")

NOTIFY = "A1B2C3D4-0000-0000-0000-000000000006"
SF_OTP = "A1B2C3D4-0000-0000-0000-000000000009"
S_OTP = "A1B2C3D4-0000-0000-0000-00000000000A"


def conn(dest, modifiers=0, subtext=""):
    return {"destinationuid": dest, "modifiers": modifiers,
            "modifiersubtext": subtext, "vitoclose": False}


def scriptfilter(uid, kw, title, subtext, script):
    return {
        "config": {
            "alfredfiltersresults": True, "alfredfiltersresultsmatchmode": 0,
            "argumenttrimmode": 0, "argumenttype": 1, "escaping": 102,
            "keyword": kw, "queuedelaycustom": 3,
            "queuedelayimmediatelyinitially": True, "queuedelaymode": 0,
            "queuemode": 1, "runningsubtext": "", "script": script,
            "scriptargtype": 0, "scriptfile": "", "subtext": subtext,
            "title": title, "type": 0, "withspace": True,
        },
        "type": "alfred.workflow.input.scriptfilter", "uid": uid, "version": 3,
    }


def runscript(uid, script):
    # scriptargtype 1 is the one that passes the query as argv, so "$1" below
    # is populated. With 0 the script runs with no arguments at all, which is
    # how this shipped originally: every action saw an empty "$1".
    return {
        "config": {"concurrently": False, "escaping": 102, "script": script,
                   "scriptargtype": 1, "scriptfile": "", "type": 0},
        "type": "alfred.workflow.action.script", "uid": uid, "version": 2,
    }


objects = [
    # Keyword is driven by a configurable variable, per the Gallery style guide.
    scriptfilter(SF_OTP, "{var:otpkeyword}", "Verification codes",
                 "Copy a time-based code for a stored account",
                 "/usr/bin/python3 totp.py --alfred"),
    runscript(S_OTP, './copy-otp.sh "$1"'),
    {
        "config": {"lastpathcomponent": False, "onlyshowifquerypopulated": True,
                   "removeextension": False, "text": "{query}",
                   "title": "Verification code"},
        "type": "alfred.workflow.output.notification", "uid": NOTIFY,
        "version": 1,
    },
]

connections = {
    SF_OTP: [conn(S_OTP)],
    S_OTP: [conn(NOTIFY)],
}

uidata = {
    SF_OTP: {"xpos": 40, "ypos": 40},
    S_OTP: {"xpos": 300, "ypos": 40},
    NOTIFY: {"xpos": 560, "ypos": 40},
}

# Gallery requires configuration to be exposed as Workflow Configuration.
userconfig = [
    {
        "config": {"default": "otp", "placeholder": "otp",
                   "required": True, "trim": True},
        "description": "The keyword used to copy a verification code.",
        "label": "Keyword", "type": "textfield", "variable": "otpkeyword",
    },
    {
        "config": {"default": "45", "placeholder": "45",
                   "required": False, "trim": True},
        "description": "Seconds before the clipboard is cleared, if it still "
                       "holds the copied value. Set to 0 to never clear.",
        "label": "Clear clipboard after", "type": "textfield",
        "variable": "CLEAR_CLIPBOARD_AFTER",
    },
]

readme = """## Setup

Store a seed, once per account:

```
python3 totp.py --store "you@example.com"     # paste the secret, then Ctrl-D
```

Seeds are kept in your login keychain, never in this workflow.

Requires macOS Sequoia or later. No Accessibility permission is needed.

## Usage

Copy a time-based verification code for a stored account via the `otp` keyword.

* <kbd>↩</kbd> Copy the current code.

The clipboard is cleared after the delay set in the Workflow’s Configuration, \
but only if it still holds the copied value.

Codes are generated locally from the stored seed (RFC 6238), so this works \
offline and never opens the Passwords app.
"""

wf = {
    # Bundle IDs are conventionally lowercase; GitHub usernames need not be.
    "bundleid": f"com.github.{GH_USER.lower()}.passwordsquickcopy",
    "category": "Productivity",
    "connections": connections,
    "createdby": AUTHOR,
    "description": "Copy a time-based verification code to the clipboard, "
                   "generated locally from a seed in your login keychain.",
    "disabled": False,
    "name": "Passwords Quick Copy",
    "objects": objects,
    "readme": readme,
    "uidata": uidata,
    "userconfigurationconfig": userconfig,
    "variables": {"otpkeyword": "otp", "CLEAR_CLIPBOARD_AFTER": "45"},
    "variablesdontexport": [],
    "version": VERSION,
    "webaddress": f"https://github.com/{GH_USER}/{REPO}",
}

path = os.path.join(SRC, "info.plist")
with open(path, "wb") as f:
    plistlib.dump(wf, f)

with open(path, "rb") as f:
    back = plistlib.load(f)

uids = {o["uid"] for o in back["objects"]}
for src, arr in back["connections"].items():
    assert src in uids, f"connection source {src} missing"
    for c in arr:
        assert c["destinationuid"] in uids, f"dest {c['destinationuid']} missing"
assert set(back["uidata"]) == uids, "uidata does not match objects"

# Gallery checks we can enforce ourselves.
declared = {c["variable"] for c in back["userconfigurationconfig"]}
assert "otpkeyword" in declared, "keyword must be user-configurable"
assert back["objects"][0]["config"]["keyword"] == "{var:otpkeyword}"
assert len(back["variables"]["otpkeyword"]) >= 3, "keyword must be >= 3 chars"
print("info.plist OK -", len(back["objects"]), "objects,",
      sum(len(v) for v in back["connections"].values()), "connections,",
      len(back["userconfigurationconfig"]), "config items")
