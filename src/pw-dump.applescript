#!/usr/bin/osascript

-- Dumps the accessibility tree of the Passwords app window, plus the
-- context menu of the first result row. Use this if `pass` cannot find
-- something: the output shows exactly what the UI looks like on your
-- version of macOS.
--
--   pwdump <query>
--
-- The dump is REDACTED by default: element roles, subroles and the names of
-- interface controls are kept, but anything that could hold one of your
-- entries -- static text, text fields, table rows, links -- is replaced with a
-- character count. That keeps the output safe to attach to a public bug
-- report. Pass "full" as a second argument to disable redaction; the file then
-- contains your account names and should not be shared.

on run argv
	set theQuery to ""
	if (count of argv) > 0 then set theQuery to item 1 of argv

	set redact to true
	if (count of argv) > 1 then
		if (item 2 of argv) is "full" then set redact to false
	end if

	do shell script "open -a Passwords"

	set outText to "Passwords UI dump" & linefeed
	set outText to outText & "macOS: " & (do shell script "sw_vers -productVersion") & linefeed
	if redact then
		set outText to outText & "Query: [redacted " & (count of theQuery) & " chars]" & linefeed
		set outText to outText & "Redaction: ON -- user data replaced with character counts." & linefeed
	else
		set outText to outText & "Query: " & theQuery & linefeed
		set outText to outText & "Redaction: OFF -- THIS FILE CONTAINS YOUR ACCOUNT DATA. Do not post it publicly." & linefeed
	end if
	set outText to outText & linefeed

	tell application "System Events"
		tell process "Passwords"
			my waitForWindow()

			if theQuery is not "" then
				set sf to my findSearchField(window 1)
				if sf is not missing value then
					set focused of sf to true
					delay 0.1
					keystroke theQuery
					delay 0.8
				end if
			end if

			set outText to outText & "=== WINDOW TREE ===" & linefeed
			set outText to outText & my dumpTree(window 1, 0, redact)

			-- Context menu of the first row, which is what `pass` clicks.
			-- These names are kept verbatim: they are the strings the workflow
			-- matches on, and are what a localisation bug report needs.
			set theList to my findList(window 1, 0)
			if theList is not missing value then
				set outText to outText & linefeed & "=== CONTEXT MENU OF FIRST ROW ===" & linefeed
				try
					set r1 to row 1 of theList
					set selected of r1 to true
					delay 0.3
					perform action "AXShowMenu" of r1
					delay 0.5
					repeat with mi in (menu items of menu 1 of r1)
						try
							set outText to outText & "  - " & (name of mi) & linefeed
						end try
					end repeat
					key code 53
				on error errMsg
					set outText to outText & "  (failed: " & errMsg & ")" & linefeed
				end try
			else
				set outText to outText & linefeed & "=== NO LIST FOUND ===" & linefeed
			end if
		end tell
	end tell

	set outText to outText & linefeed & "(Please skim this file before attaching it to a bug report.)" & linefeed

	-- Written directly rather than through `do shell script`, so that
	-- non-ASCII menu names on localised systems survive intact.
	set outFile to (POSIX path of (path to desktop)) & "passwords-ui-dump.txt"
	set fh to open for access (POSIX file outFile) with write permission
	try
		set eof fh to 0
		write outText to fh as «class utf8»
		close access fh
	on error errMsg
		try
			close access fh
		end try
		error errMsg
	end try

	do shell script "open -R " & quoted form of outFile

	if redact then
		return "Dump saved to Desktop (redacted)"
	else
		return "Dump saved to Desktop -- UNREDACTED, contains your data"
	end if
end run


-- Wait for a Passwords window that is actually usable.
--
-- When Passwords launches locked it puts up a window, tears it straight back
-- down while the separate authentication agent takes over the screen, and only
-- shows the real one once you have authenticated. While that is happening the
-- process has zero windows, and a `window 1` reference captured on the first
-- flicker goes stale: every later lookup fails with -1719 "Invalid index".
-- So require the window to still be there a moment after first seeing it, and
-- allow enough time for a human to reach for Touch ID.
on waitForWindow()
	set startTime to current date
	tell application "System Events"
		tell process "Passwords"
			repeat
				if (exists window 1) then
					delay 0.5
					if (exists window 1) then return
				end if
				delay 0.3
				if ((current date) - startTime) > 45 then
					error "No Passwords window appeared. If Passwords is locked, unlock it with Touch ID or your password, then run this again."
				end if
			end repeat
		end tell
	end tell
end waitForWindow


-- Roles whose name/description are interface furniture rather than user data.
-- Anything not listed here gets redacted.
on isChrome(roleStr)
	set safeRoles to {"AXApplication", "AXWindow", "AXButton", "AXMenu", ¬
		"AXMenuItem", "AXMenuBar", "AXMenuBarItem", "AXMenuButton", ¬
		"AXToolbar", "AXToolbarButton", "AXTabGroup", "AXRadioButton", ¬
		"AXCheckBox", "AXPopUpButton", "AXSplitGroup", "AXSplitter", ¬
		"AXScrollArea", "AXScrollBar", "AXGroup", "AXOutline", "AXTable", ¬
		"AXList", "AXColumn", "AXSheet", "AXDisclosureTriangle", ¬
		"AXProgressIndicator", "AXBusyIndicator", "AXUnknown"}
	repeat with rr in safeRoles
		if (rr as string) is roleStr then return true
	end repeat
	return false
end isChrome


on maskText(roleStr, theText, redact)
	set t to theText as string
	if t is "" then return ""
	if redact is false then return t
	if my isChrome(roleStr) then return t
	return "[redacted " & (count of t) & " chars]"
end maskText


on dumpTree(el, depth, redact)
	if depth > 10 then return ""
	set padStr to ""
	repeat depth times
		set padStr to padStr & "  "
	end repeat

	set ln to padStr
	set roleStr to ""
	tell application "System Events"
		try
			set ln to ln & (class of el as string)
		end try
		try
			set roleStr to role of el
			set ln to ln & " [" & roleStr & "]"
		end try
		try
			set sr to subrole of el
			if sr is not missing value then set ln to ln & " sub=" & sr
		end try
		try
			set nm to name of el
			if nm is not missing value then
				set nm to my maskText(roleStr, nm, redact)
				if nm is not "" then set ln to ln & " name=\"" & nm & "\""
			end if
		end try
		try
			set ds to description of el
			if ds is not missing value then
				set ds to my maskText(roleStr, ds, redact)
				if ds is not "" then set ln to ln & " desc=\"" & ds & "\""
			end if
		end try
		try
			set vl to value of el
			if vl is not missing value then
				-- Booleans and numbers are states (checked, selected, position),
				-- never secrets, so they are always shown in full.
				if (class of vl is boolean) or (class of vl is integer) or (class of vl is real) then
					set ln to ln & " value=" & (vl as string)
				else
					set vs to vl as string
					if redact then
						if vs is not "" then set ln to ln & " value=[redacted " & (count of vs) & " chars]"
					else
						if (count of vs) > 60 then set vs to (text 1 thru 60 of vs) & "..."
						if vs is not "" then set ln to ln & " value=\"" & vs & "\""
					end if
				end if
			end if
		end try
	end tell

	set outText to ln & linefeed
	tell application "System Events"
		try
			set kids to UI elements of el
			set kidCount to count of kids
			set shown to kidCount
			-- Long lists: only show the first few rows.
			if shown > 8 then set shown to 8
			repeat with i from 1 to shown
				set outText to outText & my dumpTree(item i of kids, depth + 1, redact)
			end repeat
			if kidCount > 8 then
				set outText to outText & padStr & "  ... " & (kidCount - 8) & " more siblings" & linefeed
			end if
		end try
	end tell
	return outText
end dumpTree


on findSearchField(root)
	tell application "System Events"
		try
			repeat with tf in (text fields of root)
				try
					if subrole of tf is "AXSearchField" then return contents of tf
				end try
			end repeat
		end try
		try
			repeat with child in (UI elements of root)
				set r to my findSearchField(child)
				if r is not missing value then return r
			end repeat
		end try
	end tell
	return missing value
end findSearchField


on findList(root, depth)
	if depth > 8 then return missing value
	tell application "System Events"
		try
			repeat with o in (outlines of root)
				try
					if (count of rows of o) > 0 then return contents of o
				end try
			end repeat
		end try
		try
			repeat with t in (tables of root)
				try
					if (count of rows of t) > 0 then return contents of t
				end try
			end repeat
		end try
		try
			repeat with child in (UI elements of root)
				set r to my findList(child, depth + 1)
				if r is not missing value then return r
			end repeat
		end try
	end tell
	return missing value
end findList
