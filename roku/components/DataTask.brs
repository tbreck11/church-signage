' ============================================================
' DataTask
' Fetches schedule.json from GitHub, figures out which items
' should be showing right now, downloads their images into
' tmp:/, and publishes the result as m.top.playlist.
'
' On any failure this task leaves previously-cached image files
' in tmp:/ alone, so a transient network problem just means the
' screen keeps showing the last content it successfully loaded.
' ============================================================

sub Init()
    m.top.functionName = "Execute"
end sub

sub Execute()
    cfg = AppConfig()
    fs = CreateObject("roFileSystem")

    body = FetchScheduleBody(cfg)
    if body = invalid or body = ""
        SetResult([], "error", "Could not reach schedule.json (network or URL problem).")
        return
    end if

    json = ParseJson(body)
    if json = invalid or json.items = invalid
        SetResult([], "error", "schedule.json did not parse. Check it is valid JSON with an ""items"" array.")
        return
    end if

    now = NowInfo()

    active = []
    for each item in json.items
        if ItemActiveNow(item, now)
            active.push(item)
        end if
    end for

    usedDefault = false
    if active.count() = 0 and json.fallback <> invalid
        for each item in json.fallback
            active.push(item)
        end for
        usedDefault = true
    end if

    if active.count() = 0
        SetResult([], "empty", "No schedule items are active right now, and no default is set.")
        return
    end if

    ' Each refresh saves images under a new name so the Poster's texture
    ' cache can't keep showing an old copy of an image that was replaced.
    stamp = CreateObject("roDateTime").AsSeconds().ToStr()

    playlist = []
    anyFailed = false
    for each item in active
        if item.image <> invalid and item.image <> ""
            localPath = DownloadImage(cfg, fs, item.image, stamp)
            if localPath <> invalid
                dur = 10
                if item.duration <> invalid and item.duration > 0
                    dur = item.duration
                end if
                playlist.push({ localPath: localPath, duration: dur, label: item.image })
            else
                anyFailed = true
            end if
        end if
    end for

    if playlist.count() = 0
        SetResult([], "error", "None of the scheduled images could be downloaded or found in cache.")
        return
    end if

    msg = "OK"
    if usedDefault then msg = "Showing default content (nothing scheduled for right now)."
    if anyFailed then msg = msg + " Some images failed to download and were skipped."
    CleanupCache(fs, playlist, m.top.playlist)
    SetResult(playlist, "ok", msg)
end sub

' Deletes cached images that neither the new playlist nor the one still on
' screen uses, so tmp:/ doesn't fill up with old copies.
sub CleanupCache(fs as object, newPlaylist as object, oldPlaylist as dynamic)
    keep = {}
    for each entry in newPlaylist
        keep[entry.localPath] = true
    end for
    if oldPlaylist <> invalid
        for each entry in oldPlaylist
            keep[entry.localPath] = true
        end for
    end if
    for each name in fs.GetDirectoryListing("tmp:/")
        path = "tmp:/" + name
        if Left(name, 4) = "sig_" and not keep.DoesExist(path)
            fs.Delete(path)
        end if
    end for
end sub

function NewTransfer(url as string) as object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnablePeerVerification(true)
    xfer.EnableHostVerification(true)
    xfer.SetUrl(url)
    xfer.SetMessagePort(CreateObject("roMessagePort"))
    return xfer
end function

' Waits for an async transfer to finish. Returns the roUrlEvent, or invalid
' if it timed out (a hung request would otherwise stall every later refresh).
function WaitForTransfer(xfer as object, cfg as object) as dynamic
    msg = wait(cfg.requestTimeoutSeconds * 1000, xfer.GetMessagePort())
    if type(msg) = "roUrlEvent" then return msg
    xfer.AsyncCancel()
    return invalid
end function

sub SetResult(playlist as object, status as string, message as string)
    m.top.playlist = playlist
    m.top.status = status
    m.top.statusMessage = message
end sub

function FetchScheduleBody(cfg as object) as dynamic
    xfer = NewTransfer(ScheduleUrl(cfg))
    if not xfer.AsyncGetToString() then return invalid
    msg = WaitForTransfer(xfer, cfg)
    if msg = invalid then return invalid
    code = msg.GetResponseCode()
    if code < 200 or code >= 300 then return invalid
    return msg.GetString()
end function

function NowInfo() as object
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    dayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    return {
        dayName: dayNames[dt.GetDayOfWeek()]
        minutes: dt.GetHours() * 60 + dt.GetMinutes()
    }
end function

' Parses "HH:MM" into minutes-since-midnight. Returns -1 on bad input.
function ParseHHMM(s as dynamic) as integer
    if s = invalid or type(s) <> "roString" then return -1
    parts = s.Split(":")
    if parts.Count() <> 2 then return -1
    h = Int(Val(parts[0]))
    mins = Int(Val(parts[1]))
    if h < 0 or h > 23 or mins < 0 or mins > 59 then return -1
    return h * 60 + mins
end function

function ItemActiveNow(item as object, now as object) as boolean
    if item.enabled <> invalid and item.enabled = false then return false

    ' --- day check ---
    dayOk = true
    if item.days <> invalid
        d = item.days
        if type(d) = "roString"
            dayOk = (LCase(d) = "all")
        else if type(d) = "roArray"
            dayOk = false
            for each dayVal in d
                if LCase(dayVal) = "all" or LCase(dayVal) = now.dayName
                    dayOk = true
                end if
            end for
        end if
    end if
    if not dayOk then return false

    ' --- time-of-day check ---
    if item.startTime = invalid and item.endTime = invalid then return true

    startMin = ParseHHMM(item.startTime)
    endMin = ParseHHMM(item.endTime)
    if startMin = -1 or endMin = -1 then return true ' malformed window -> don't block content

    if startMin <= endMin
        return now.minutes >= startMin and now.minutes < endMin
    else
        ' window wraps past midnight, e.g. 22:00-06:00
        return now.minutes >= startMin or now.minutes < endMin
    end if
end function

' Downloads an image referenced in the schedule to tmp:/sig_<stamp>_<name>,
' writing to a temp name first and renaming only on success, so a failed
' download never destroys a previously-cached good copy.
function DownloadImage(cfg as object, fs as object, filename as string, stamp as string) as dynamic
    safe = SafeFileName(filename)
    finalPath = "tmp:/sig_" + stamp + "_" + safe
    partPath = "tmp:/part_" + safe

    fs.Delete(partPath)
    xfer = NewTransfer(ImageUrl(cfg, filename))
    code = -1
    if xfer.AsyncGetToFile(partPath)
        msg = WaitForTransfer(xfer, cfg)
        if msg <> invalid then code = msg.GetResponseCode()
    end if

    if code >= 200 and code < 300
        fs.Delete(finalPath)
        if fs.Rename(partPath, finalPath) then return finalPath
    end if

    fs.Delete(partPath)
    return FindCachedImage(fs, safe) ' fall back to last known-good cached copy
end function

' Newest previously-downloaded copy of an image, or invalid if none.
function FindCachedImage(fs as object, safe as string) as dynamic
    best = invalid
    bestStamp = -1
    re = CreateObject("roRegex", "^sig_(\d+)_(.+)$", "")
    for each name in fs.GetDirectoryListing("tmp:/")
        parts = re.Match(name)
        if parts.Count() = 3 and parts[2] = safe
            nameStamp = Val(parts[1])
            if nameStamp > bestStamp
                bestStamp = nameStamp
                best = "tmp:/" + name
            end if
        end if
    end for
    return best
end function

function SafeFileName(s as string) as string
    out = ""
    for i = 0 to Len(s) - 1
        c = Mid(s, i + 1, 1)
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c = "." or c = "_" or c = "-"
            out = out + c
        else
            out = out + "_"
        end if
    end for
    return out
end function
