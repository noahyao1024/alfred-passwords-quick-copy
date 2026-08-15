import plistlib, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Set these before publishing. GH_USER is used for the bundle ID, which must be
# unique and is conventionally reverse-domain based on the author.
GH_USER = os.environ.get("GH_USER", "YOUR-GITHUB-USERNAME")
AUTHOR = os.environ.get("AUTHOR", "Your Name")
REPO = os.environ.get("REPO", "alfred-passwords-quick-copy")
# Must track the release tag: Alfred shows this and uses it for update checks,
# so a bundle claiming 1.0.0 inside a v0.1.0 release is a real mismatch.
VERSION = os.environ.get("VERSION", "0.1.0")
SRC = os.path.join(HERE, "src")

KW      = "A1B2C3D4-0000-0000-0000-000000000001"
S_PASS  = "A1B2C3D4-0000-0000-0000-000000000002"
S_USER  = "A1B2C3D4-0000-0000-0000-000000000003"
S_CODE  = "A1B2C3D4-0000-0000-0000-000000000004"
S_SITE  = "A1B2C3D4-0000-0000-0000-000000000005"
NOTIFY  = "A1B2C3D4-0000-0000-0000-000000000006"
KW_DUMP = "A1B2C3D4-0000-0000-0000-000000000007"
S_DUMP  = "A1B2C3D4-0000-0000-0000-000000000008"

CMD, OPT, CTRL = 1048576, 524288, 262144


def conn(dest, modifiers=0, subtext=""):
    return {"destinationuid": dest, "modifiers": modifiers,
            "modifiersubtext": subtext, "vitoclose": False}


def keyword(uid, kw, title, subtext, argumenttype=0):
    # argumenttype: 0 = required, 1 = optional, 2 = none.
    return {
        "config": {"argumenttype": argumenttype, "keyword": kw,
                   "subtext": subtext, "text": title, "withspace": True},
        "type": "alfred.workflow.input.keyword", "uid": uid, "version": 1,
    }


def runscript(uid, script):
    return {
        "config": {"concurrently": False, "escaping": 102, "script": script,
                   "scriptargtype": 0, "scriptfile": "", "type": 0},
        "type": "alfred.workflow.action.script", "uid": uid, "version": 2,
    }


objects = [
    # Keyword is driven by a configurable variable, per the Gallery style guide.
    keyword(KW, "{var:keyword}", "Copy from Passwords",
            "\u21a9 password   \u2318 username   \u2325 verification code   \u2303 website"),
    runscript(S_PASS, './copy.sh password "$1"'),
    runscript(S_USER, './copy.sh username "$1"'),
    runscript(S_CODE, './copy.sh code "$1"'),
    runscript(S_SITE, './copy.sh website "$1"'),
    {
        "config": {"lastpathcomponent": False, "onlyshowifquerypopulated": True,
                   "removeextension": False, "text": "{query}", "title": "Passwords"},
        "type": "alfred.workflow.output.notification", "uid": NOTIFY, "version": 1,
    },
    # The query is optional here: `pwdump` on its own dumps the unfiltered
    # window, which is the common case when nothing resolves at all.
    keyword(KW_DUMP, "pwdump", "Dump Passwords UI tree",
            "Diagnostics: saves a redacted accessibility tree to your Desktop",
            argumenttype=1),
    runscript(S_DUMP, '/usr/bin/osascript pw-dump.applescript "$1"'),
]

connections = {
    KW: [conn(S_PASS, 0, "copy password"),
         conn(S_USER, CMD, "copy username"),
         conn(S_CODE, OPT, "copy verification code"),
         conn(S_SITE, CTRL, "copy website")],
    S_PASS: [conn(NOTIFY)], S_USER: [conn(NOTIFY)],
    S_CODE: [conn(NOTIFY)], S_SITE: [conn(NOTIFY)],
    KW_DUMP: [conn(S_DUMP)], S_DUMP: [conn(NOTIFY)],
}

uidata = {
    KW: {"xpos": 40, "ypos": 40}, S_PASS: {"xpos": 300, "ypos": 20},
    S_USER: {"xpos": 300, "ypos": 120}, S_CODE: {"xpos": 300, "ypos": 220},
    S_SITE: {"xpos": 300, "ypos": 320}, NOTIFY: {"xpos": 560, "ypos": 170},
    KW_DUMP: {"xpos": 40, "ypos": 440}, S_DUMP: {"xpos": 300, "ypos": 440},
}

# Gallery requires configuration to be exposed as Workflow Configuration.
userconfig = [
    {
        "config": {"default": "pass", "placeholder": "pass",
                   "required": True, "trim": True},
        "description": "The keyword used to search your passwords.",
        "label": "Keyword", "type": "textfield", "variable": "keyword",
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

Grant Alfred Accessibility permission in System Settings \u2192 Privacy & Security \
\u2192 Accessibility. Apple provides no API for the Passwords app, so this workflow \
controls it through the Accessibility API.

Requires macOS Sequoia or later.

## Usage

Search your Apple Passwords entries and copy a field to the clipboard via the \
`pass` keyword.

* <kbd>\u21a9</kbd> Copy the password.
* <kbd>\u2318</kbd><kbd>\u21a9</kbd> Copy the username.
* <kbd>\u2325</kbd><kbd>\u21a9</kbd> Copy the verification code.
* <kbd>\u2303</kbd><kbd>\u21a9</kbd> Copy the website.

The clipboard is cleared after the delay set in the Workflow\u2019s Configuration, \
but only if it still holds the copied value.

Alternatively, save the Passwords app\u2019s accessibility tree to your Desktop via \
the `pwdump` keyword. Use it if a field cannot be found. The dump is redacted \
\u2014 your entries are replaced with character counts \u2014 so it is safe to \
attach to a bug report.
"""

wf = {
    # Bundle IDs are conventionally lowercase; GitHub usernames need not be.
    "bundleid": f"com.github.{GH_USER.lower()}.passwordsquickcopy",
    "category": "Productivity",
    "connections": connections,
    "createdby": AUTHOR,
    "description": "Search the Apple Passwords app and copy a password, "
                   "username, verification code or website to the clipboard.",
    "disabled": False,
    "name": "Passwords Quick Copy",
    "objects": objects,
    "readme": readme,
    "uidata": uidata,
    "userconfigurationconfig": userconfig,
    "variables": {"keyword": "pass", "CLEAR_CLIPBOARD_AFTER": "45"},
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
assert "keyword" in declared and back["objects"][0]["config"]["keyword"] == "{var:keyword}"
assert len(back["variables"]["keyword"]) >= 3, "default keyword must be >= 3 chars"
assert len(back["objects"][6]["config"]["keyword"]) >= 3, "pwdump keyword too short"
print("info.plist OK -", len(back["objects"]), "objects,",
      sum(len(v) for v in back["connections"].values()), "connections,",
      len(back["userconfigurationconfig"]), "config items")
