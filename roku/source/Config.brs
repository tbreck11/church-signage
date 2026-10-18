' ============================================================
' Church Signage - configuration
'
' Edit the three values below to point at YOUR GitHub repo,
' then re-zip the app (see SETUP.md). Nothing else in this
' project needs to change for day-to-day use -- once this is
' set, you manage content entirely through the web page, not
' by re-editing or re-sideloading this app.
' ============================================================
function AppConfig() as object
    return {
        githubUser: "tbreck11"
        githubRepo: "church-signage"
        githubBranch: "main"

        ' How often (seconds) the app re-checks schedule.json for
        ' changes and re-evaluates which items should be active.
        refreshIntervalSeconds: 300

        ' Give up on a schedule/image download after this many seconds
        ' so one stuck request can't stall all later refreshes.
        requestTimeoutSeconds: 60

        ' Minimum seconds any error/status message stays visible.
        minStatusSeconds: 3
    }
end function

' Raw GitHub URL for the schedule file. A random query string is
' appended to discourage any intermediate HTTP caching from
' serving a stale copy.
function ScheduleUrl(cfg as object) as string
    bust = CreateObject("roDateTime").AsSeconds().ToStr()
    return "https://raw.githubusercontent.com/" + cfg.githubUser + "/" + cfg.githubRepo + "/" + cfg.githubBranch + "/schedule.json?t=" + bust
end function

' Raw GitHub URL for an image file stored in the repo's /images folder.
function ImageUrl(cfg as object, filename as string) as string
    return "https://raw.githubusercontent.com/" + cfg.githubUser + "/" + cfg.githubRepo + "/" + cfg.githubBranch + "/images/" + filename
end function
