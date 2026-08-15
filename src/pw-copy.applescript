#!/usr/bin/osascript

-- pw-copy.applescript <field> <query>
--   field: password | username | code | website
--
-- Apple exposes no API for the Passwords app (the data lives in the
-- data-protection keychain, which has no command-line access), so this
-- drives the app's UI through the Accessibility API instead.

on run argv
	if (count of argv) < 2 then error "Usage: pw-copy <field> <query>"
	set fieldKey to item 1 of argv
	set searchQuery to item 2 of argv

	-- The context-menu item we are looking for, per field. Several spellings
	-- are accepted per field: the exact wording has shifted between macOS
	-- releases, and matching only one of them is what breaks first.
	if fieldKey is "username" then
		set menuKeywords to {"User Name", "Username", "User name"}
	else if fieldKey is "code" then
		set menuKeywords to {"Verification Code", "One-Time Code"}
	else if fieldKey is "website" then
		set menuKeywords to {"Website", "Web Site"}
	else
		set menuKeywords to {"Password"}
	end if

	-- Was the app already running? If not, we quit it again afterwards.
	tell application "System Events"
		set wasRunning to (exists process "Passwords")
	end tell

	set copiedLabel to missing value
	set availableItems to ""

	do shell script "open -a Passwords"

	try
		tell application "System Events"
		if not (exists process "Passwords") then
			delay 0.5
			if not (exists process "Passwords") then error "Passwords app did not launch."
		end if

		tell process "Passwords"
			-- Wait for a usable window. Allow a long timeout: the user may
			-- have to authenticate with Touch ID or their login password
			-- first, during which the process has no windows at all.
			my waitForWindow()

			-- Wait for the search field, which only exists once unlocked.
			-- Timed against the clock, not by adding up the delays: each
			-- findSearchField pass is a few hundred Apple Events and costs
			-- far more than the 0.2s delay below, so counting delays alone
			-- turned a "30 second" timeout into two and a half minutes.
			set searchField to missing value
			set startTime to current date
			repeat
				set searchField to my findSearchField(window 1)
				if searchField is not missing value then exit repeat
				delay 0.2
				if ((current date) - startTime) > 30 then
					error "Timed out waiting for Passwords to unlock. Unlock it with Touch ID or your password, then try again."
				end if
			end repeat

			-- Type the query. Setting the value directly does not always
			-- trigger filtering, so focus the field and type into it.
			-- keystroke goes to the frontmost app, so make sure that is us.
			set frontmost to true
			set focused of searchField to true
			try
				set value of searchField to ""
			end try
			delay 0.1
			keystroke searchQuery
			delay 0.6

			-- Find the results list and the first selectable row.
			set theList to my findList(window 1, 0)
			if theList is missing value then error "Could not find the results list. Run `pwdump` and send me the output."

			set theRows to rows of theList
			if (count of theRows) is 0 then error "No entry found for " & searchQuery & "."

			-- Try the first few rows: some may be section headers.
			repeat with i from 1 to (count of theRows)
				if i > 4 then exit repeat
				set thisRow to item i of theRows
				try
					set selected of thisRow to true
					delay 0.25
					perform action "AXShowMenu" of thisRow
					delay 0.4

					set foundItem to missing value
					repeat with mi in (menu items of menu 1 of thisRow)
						set n to ""
						try
							set n to name of mi
						end try
						if n is not "" then
							set availableItems to availableItems & n & ", "
							if foundItem is missing value and n starts with "Copy" then
								repeat with mk in menuKeywords
									if n contains (mk as string) then
										set foundItem to contents of mi
										exit repeat
									end if
								end repeat
							end if
						end if
					end repeat

					if foundItem is not missing value then
						click foundItem
						delay 0.2
						set copiedLabel to my rowLabel(thisRow)
						exit repeat
					else
						key code 53 -- escape, dismiss the menu
						delay 0.2
					end if
				end try
			end repeat
		end tell
	end tell
	on error errMsg
		-- Never leave Passwords sitting in the foreground holding the user's
		-- focus because a lookup failed.
		my putAway(wasRunning)
		error errMsg
	end try

	-- Put the app away again; hiding restores focus to whatever you were using.
	my putAway(wasRunning)

	if copiedLabel is missing value then
		if availableItems is "" then
			error "No entry found for " & searchQuery & "."
		else
			error "No \"Copy " & (item 1 of menuKeywords) & "\" item for that entry. Menu offered: " & availableItems
		end if
	end if

	return my fieldLabel(fieldKey) & " copied — " & copiedLabel
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
