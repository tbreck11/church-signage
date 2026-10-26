# Church Signage — setup guide

This system has three pieces:

1. **A GitHub repo** that holds your announcement images and a `schedule.json` file saying when each one should show. This is the only "server" involved — it's free and you don't touch it directly day-to-day.
2. **The content manager web page** — where you actually upload images and build the schedule, in plain language, no code.
3. **The Roku app** (the `roku/` folder in this repo) — sideloaded once onto each signage TV's Roku. It checks the repo every 5 minutes and shows whatever should be on screen.

Set up 1 and 3 once. After that, everything day-to-day happens in the web page.

---

## 1. Create the GitHub repo (5 minutes)

1. Go to [github.com](https://github.com) and sign in (or create a free account).
2. Click **New repository**. Name it something like `church-signage`. Leave it **Public** — the images aren't sensitive, and a public repo means the Roku can fetch them with no login required. Don't add a README/gitignore/license — an empty repo is fine.
3. Note the exact **username** and **repository name** — you'll enter these into the content manager page. Note the default branch name too (usually `main`).

### Create an access token

The content manager page needs a token to upload files on your behalf.

1. On GitHub, go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. Give it a name like `signage-board`. Set **Expiration** to the longest option GitHub offers (a custom date up to a year out, or *No expiration* if it's available). The default is 30 days, and when the token expires the content manager stops logging in.
3. Under **Repository access**, choose **Only select repositories** and pick the repo you just created. (Don't give it access to anything else.)
4. Under **Permissions**, click **+ Add permissions**, choose **Contents**, then change its dropdown from *Read-only* to **Read and write**. Don't add anything else (GitHub adds *Metadata: Read-only* on its own, which is fine).
5. Generate the token and copy it somewhere safe (it starts with `github_pat_`). GitHub only shows it once.

---

## 2. Set up the content manager page

Open the **Signage Board** page (linked separately). The first time, fill in:

- **GitHub username or org**
- **Repository name**
- **Branch** (usually `main`)
- **Access token** (the `github_pat_...` value from above)

Click **Connect**. The page remembers these in your browser (not sent anywhere but GitHub), so you won't need to re-enter them next time you open it on this device. Anyone else who needs to manage content (another volunteer) enters the same details on their own device.

From here:

- **Image library** — drag in JPG/PNG files, one per announcement slide. Keep them roughly TV-shaped (landscape, e.g. 1920×1080) for the best fit.
- **Weekly schedule** — add a slide, pick the image, choose which days it should appear (tap the day letters) and a time window, and how many seconds it shows before moving to the next slide. Check **All day** to skip the time window.
- **Always show** — slides that appear whenever nothing in the weekly schedule matches (e.g. a generic welcome graphic for off-hours).
- **Save to GitHub** — writes your changes back to the repo. The Roku board picks them up automatically within about 5 minutes, no need to touch the Roku itself.

### When the page stops logging in

This almost always means the access token expired. The page will say so and walk you through it: create a new token with the same settings as above, paste it into **Access token**, and click **Connect**. Nothing else needs to change — the Roku keeps showing content the whole time, because it reads the public repo without a token. The page also shows a warning banner when the token is within two weeks of expiring.

---

## 3. Point the Roku app at your repo

The app reads the repo named in `roku/source/Config.brs`. It's already set to this repo:

```brightscript
githubUser: "tbreck11"
githubRepo: "church-signage"
githubBranch: "main"
```

Change these only if the content moves to a different repo.

## 4. Enable Developer Mode on the Roku

On the Roku remote, press: **Home ×3, Up ×2, Right, Left, Right, Left, Right.**

A screen appears with a web address (something like `http://192.168.1.xxx`). Accept the Developer Tools License Agreement and set a password — you'll need it in a second. The Roku reboots into developer mode.

## 5. Sideload the app

The deploy script builds the zip and uploads it to every TV at once. From a computer on the **same network** as the Rokus:

1. In `roku/`, edit `deploy.json` (copy `deploy.example.json` if it's missing). Put each TV's IP address (the address shown in step 4) in `rokuIps`, and the developer password in `rokuPassword`. If one TV has a different password, give it its own entry under `passwords`. `deploy.json` is git-ignored, so the password never goes to GitHub.
2. From the `roku/` folder, run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1
   ```

   To update only certain TVs, pass their IPs: `-RokuIp 192.168.1.50,192.168.1.51`.
3. The app installs and launches on each TV. You should see the splash screen, then content from GitHub within a few seconds. If a TV fails, the script still updates the rest and then lists the ones that failed.

To upload by hand instead, run the script with `-ZipOnly`. Then open `http://<roku-ip>` in a browser, log in as `rokudev`, and upload `roku/out/church-signage.zip`.

Re-run the script only when the app's code or `Config.brs` changes. Content changes never need it.

On the remote, **Back** or **OK** reloads content right away instead of leaving the app. The other buttons are ignored, except **Home**, which Roku never lets an app block.

## 6. Leave it running

Switch the TV to the Roku's input and leave the Church Signage channel open. Roku devices don't have a general "launch this app on boot" setting out of the box, so after a power cycle you may need to reopen the channel from the Roku home screen once. If this becomes a hassle, Roku's business/hospitality program offers auto-launch features worth looking into separately.

---

## Notes on how it behaves

- If the network hiccups or GitHub is briefly unreachable, the board keeps showing the last content it successfully loaded rather than going blank.
- Time windows use the Roku's local time zone (set during the Roku's own initial setup).
- A window like `22:00`–`06:00` (start later than end) is treated as spanning midnight.
- Changing content never requires touching the Roku — only changing *which repo* it reads from does.
