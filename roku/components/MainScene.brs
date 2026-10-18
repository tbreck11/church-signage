sub Init()
    m.poster = m.top.findNode("poster")
    m.statusLabel = m.top.findNode("statusLabel")
    m.advanceTimer = m.top.findNode("advanceTimer")
    m.refreshTimer = m.top.findNode("refreshTimer")
    m.dataTask = m.top.findNode("dataTask")

    m.playlist = []
    m.index = 0
    m.consecutivePosterFailures = 0

    m.dataTask.observeField("playlist", "OnPlaylist")
    m.dataTask.observeField("status", "OnStatus")

    m.advanceTimer.observeField("fire", "OnAdvance")
    m.refreshTimer.observeField("fire", "OnRefreshTimer")

    m.poster.observeField("loadStatus", "OnPosterLoadStatus")

    cfg = AppConfig()
    m.cfg = cfg

    interval = cfg.refreshIntervalSeconds
    if interval < 30 then interval = 30 ' sanity floor
    m.refreshTimer.duration = interval
    m.refreshTimer.control = "start"

    m.statusLabel.text = "Loading church signage..."
    m.statusLabel.visible = true
    m.poster.visible = false

    ' The scene must hold focus to receive remote key presses in onKeyEvent.
    m.top.setFocus(true)

    RunDataTask()
end sub

' Remote handling. An unhandled Back press closes the channel and drops the
' TV to the Roku Home screen, so Back (and OK) instead trigger an immediate
' content refresh. Every other key is swallowed so a bumped remote can't
' knock the board off screen. (The Home button itself can't be intercepted.)
function onKeyEvent(key as string, press as boolean) as boolean
    if press and (key = "back" or key = "OK")
        RunDataTask()
    end if
    return true
end function

sub RunDataTask()
    m.dataTask.control = "RUN"
end sub

sub OnRefreshTimer()
    RunDataTask()
end sub

sub OnStatus(event as object)
    status = event.getData()
    detail = m.dataTask.statusMessage

    if status = "error" or status = "empty"
        if m.playlist.count() = 0
            ' nothing has ever loaded successfully -- show why
            m.statusLabel.text = detail
            m.statusLabel.visible = true
            m.poster.visible = false
        end if
        ' if we already have a playlist on screen, a transient
        ' error just gets ignored and the current slide keeps playing
    end if
end sub

sub OnPlaylist(event as object)
    pl = event.getData()
    if pl = invalid or pl.count() = 0 then return

    m.playlist = pl
    m.index = 0
    m.consecutivePosterFailures = 0
    m.statusLabel.visible = false
    m.poster.visible = true
    ShowCurrent()
end sub

sub ShowCurrent()
    if m.playlist.count() = 0 then return
    item = m.playlist[m.index]

    dur = item.duration
    if dur = invalid or dur <= 0 then dur = 10

    m.poster.uri = item.localPath
    m.advanceTimer.duration = dur
    m.advanceTimer.control = "start"
end sub

sub OnAdvance()
    AdvanceToNext()
end sub

sub AdvanceToNext()
    if m.playlist.count() = 0 then return
    m.index = (m.index + 1) mod m.playlist.count()
    ShowCurrent()
end sub

' If a cached image is corrupt/unreadable, skip it instead of sitting
' on a blank/broken poster until the next full refresh. Guards against
' looping forever if every cached image is bad.
sub OnPosterLoadStatus(event as object)
    status = event.getData()
    if status = "failed"
        m.consecutivePosterFailures = m.consecutivePosterFailures + 1
        if m.consecutivePosterFailures < m.playlist.count() + 1
            m.advanceTimer.control = "stop"
            AdvanceToNext()
        end if
    else if status = "ready"
        m.consecutivePosterFailures = 0
    end if
end sub
