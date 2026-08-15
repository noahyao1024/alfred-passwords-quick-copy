#!/usr/bin/osascript

-- pw-copy.applescript <field> <query>
--   field: password | username | code | website
--
-- Apple exposes no API for the Passwords app (the data lives in the
-- data-protection keychain, which has no command-line access), so this
-- drives the app's UI through the Accessibility API instead.
--
-- The copy itself goes through the Edit menu, not the row's context menu.
-- On macOS 26 `perform action "AXShowMenu"` on a result row produces no
-- accessible menu at all -- nothing on the row, the outline, the process, or
-- in any new window -- so the context-menu route cannot be driven. The same
-- commands live in the menu bar under Edit, and those are exposed normally:
--
--   Copy User Name  ⇧⌘C      Copy Password   ⌥⌘C
--   Copy Code       ⌃⌘C      Copy Website    ⇧⌥⌘C
--
-- Menu item names are localised, so each field also carries its keyboard
-- shortcut as a fallback; the shortcuts are the same on every language.

on run argv
	if (count of argv) < 2 then error "Usage: pw-copy <field> <query>"
	set fieldKey to item 1 of argv
	set searchQuery to item 2 of argv

	-- Menu item names to look for, and the shortcut to fall back on.
	if fieldKey is "username" then
		set menuNames to {"Copy User Name", "Copy Username"}
		set shortMods to {command down, shift down}
	else if fieldKey is "code" then
		set menuNames to {"Copy Code", "Copy Verification Code"}
		set shortMods to {command down, control down}
	else if fieldKey is "website" then
		set menuNames to {"Copy Website", "Copy Web Site"}
		set shortMods to {command down, shift down, option down}
	else
		set menuNames to {"Copy Password"}
		set shortMods to {command down, option down}
	end if

	tell application "System Events"
		set wasRunning to (exists process "Passwords")
	end tell

	set copiedLabel to missing value

	do shell script "open -a Passwords"

	try
		tell application "System Events"
			tell process "Passwords"
				my waitForWindow()

				-- The search field only exists once unlocked, so finding it is
				-- also how we know authentication finished. Timed against the
				-- clock: each pass is hundreds of Apple Events and costs far
				-- more than the delay beside it.
				-- The lookup is wrapped because `window 1` is resolved here, in
				-- the caller, outside findSearchField's own try blocks. While
				-- the app is locked it destroys and recreates its window, so
				-- that resolution intermittently throws -1719. Treating it as
				-- "not ready yet" is what lets this keep waiting for the user
				-- to authenticate instead of giving up a second or two in.
				set searchField to missing value
				set startTime to current date
				repeat
					try
						set searchField to my findSearchField(window 1)
					on error
						set searchField to missing value
					end try
					if searchField is not missing value then exit repeat
					delay 0.2
					if ((current date) - startTime) > 60 then
						error "Timed out waiting for Passwords to unlock. Unlock it with Touch ID or your password, then try again."
					end if
				end repeat

				-- keystroke goes to the frontmost app, so make sure that is us.
				set frontmost to true
				set focused of searchField to true
				try
					set value of searchField to ""
				end try
				delay 0.1
				keystroke searchQuery
				delay 0.8

				-- There is more than one outline in this window: the sidebar
				-- (All, Passkeys, Codes, Wi-Fi, ...) is one, the results are
				-- another. Taking simply the first one found means selecting
				-- sidebar categories, which is why nothing ever copied -- the
				-- row count stayed at 5 no matter what was searched for.
				--
				-- Rather than guess which outline is which, try them all. A
				-- row is the right one only if selecting it makes the Copy
				-- command become enabled, so that check does the identifying.
				set allLists to my collectLists(window 1)
				if (count of allLists) is 0 then error "Could not find the results list. Run `pwdump` and send me the output."

				set copyItem to missing value
				repeat with lst in allLists
					set theRows to {}
					try
						set theRows to rows of lst
					end try
					repeat with i from 1 to (count of theRows)
						if i > 10 then exit repeat
						try
							set r to item i of theRows
							set selected of r to true
							delay 0.3
							set copyItem to my findCopyItem(menuNames)
							if copyItem is not missing value then
								if enabled of copyItem then
									set copiedLabel to my rowLabel(r)
									exit repeat
								end if
							end if
							set copyItem to missing value
						end try
					end repeat
					if copiedLabel is not missing value then exit repeat
				end repeat

				if copiedLabel is missing value then
					error "No entry found for " & searchQuery & "."
				end if

				-- Click the menu item, or use the shortcut if the names did
				-- not match, which is what happens on a localised system.
				if copyItem is not missing value then
					click copyItem
				else
					keystroke "c" using shortMods
				end if
				delay 0.3
			end tell
		end tell
	on error errMsg
		-- Never leave Passwords sitting in the foreground holding the user's
		-- focus because a lookup failed.
		my putAway(wasRunning)
		error errMsg
	end try

	my putAway(wasRunning)

	return my fieldLabel(fieldKey) & " copied — " & copiedLabel
end run


-- Every outline and table in the window, outermost first. Deliberately not
-- "the first one that has rows": that is the sidebar.
on collectLists(root)
	set acc to {}
	my gatherLists(root, 0, acc)
	return acc
end collectLists


on gatherLists(el, depth, acc)
	if depth > 9 then return
	tell application "System Events"
		try
			repeat with o in (outlines of el)
				try
					if (count of rows of o) > 0 then set end of acc to contents of o
				end try
			end repeat
		end try
		try
			repeat with t in (tables of el)
				try
					if (count of rows of t) > 0 then set end of acc to contents of t
				end try
			end repeat
		end try
		try
			repeat with c in (UI elements of el)
				my gatherLists(c, depth + 1, acc)
			end repeat
		end try
	end tell
end gatherLists


-- Entry rows before section headers, otherwise original order.
on entryRowsFirst(theRows)
	set deep to {}
	set shallow to {}
	tell application "System Events"
		repeat with r in theRows
			set lvl to 0
			try
				set lvl to value of attribute "AXDisclosureLevel" of r
			end try
			if lvl > 0 then
				set end of deep to contents of r
			else
				set end of shallow to contents of r
			end if
		end repeat
	end tell
	set out to {}
	repeat with r in deep
		if (count of out) ≥ 8 then exit repeat
		set end of out to r
	end repeat
	repeat with r in shallow
		if (count of out) ≥ 8 then exit repeat
		set end of out to r
	end repeat
	return out
end entryRowsFirst


-- The Copy command in the Edit menu, by any of its known names.
on findCopyItem(menuNames)
	tell application "System Events"
		tell process "Passwords"
			repeat with nm in menuNames
				try
					set mi to menu item (nm as string) of menu 1 of menu bar item "Edit" of menu bar 1
					if exists mi then return contents of mi
				end try
			end repeat
		end tell
	end tell
	return missing value
end findCopyItem


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
					error "No Passwords window appeared. If Passwords is locked, unlock it with Touch ID or your password, then try again."
				end if
			end repeat
		end tell
	end tell
end waitForWindow


-- Hide Passwords again, or quit it if we were the ones who launched it.
-- A quit sent while the app is still putting up its unlock prompt is
-- ignored, which is exactly the state a failed lookup tends to leave it in,
-- so the quit is retried once after a short pause.
on putAway(wasRunning)
	if wasRunning then
		try
			tell application "System Events" to set visible of process "Passwords" to false
		end try
	else
		try
			tell application "Passwords" to quit
		end try
		delay 0.6
		try
			if running of application "Passwords" then
				tell application "Passwords" to quit
			end if
		end try
	end if
end putAway


-- Find the search field anywhere in the window.
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


-- Find the first outline/table that actually contains rows.
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


-- Best-effort human-readable name for the selected row.
on rowLabel(theRow)
	tell application "System Events"
		try
			set texts to value of every static text of UI element 1 of theRow
			set out to ""
			repeat with t in texts
				if (t as string) is not "" then
					if out is "" then
						set out to t as string
					else
						set out to out & " · " & (t as string)
					end if
				end if
			end repeat
			if out is not "" then return out
		end try
		try
			return description of theRow
		end try
	end tell
	return "entry"
end rowLabel


on fieldLabel(fieldKey)
	if fieldKey is "username" then return "Username"
	if fieldKey is "code" then return "Verification code"
	if fieldKey is "website" then return "Website"
	return "Password"
end fieldLabel
