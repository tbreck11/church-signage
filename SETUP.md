# Church Signage — setup guide

This system has three pieces:

1. **A GitHub repo** that holds your announcement images and a `schedule.json` file saying when each one should show. This is the only "server" involved — it's free and you don't touch it directly day-to-day.
2. **The content manager web page** — where you actually upload images and build the schedule, in plain language, no code.
3. **The Roku app** (`church-signage.zip`) — sideloaded once onto your church's Roku. It checks the repo every 5 minutes and shows whatever should be on screen.

Set up 1 and 3 once. After that, everything day-to-day happens in the web page.

---

## 1. Create the GitHub repo (5 minutes)

1. Go to [github.com](https://github.com) and sign in (or create a free account).
2. Click **New repository**. Name it something like `church-signage`. Leave it **Public** — the images aren't sensitive, and a public repo means the Roku can fetch them with no login required. Don't add a README/gitignore/license — an empty repo is fine.
3. Note the exact **username** and **repository name** — you'll enter these into the content manager page. Note the default branch name too (usually `main`).

### Create an access token

The content manager page needs a token to upload files on your behalf.

1. On GitHub, go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. Give it a name like `signage-board`.
3. Under **Repository access**, choose **Only select repositories** and pick the repo you just created. (Don't give it access to anything else.)
4. Under **Permissions → Repository permissions**, set **Contents** to **Read and write**. Leave everything else as "No access."
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

---

## 3. Point the Roku app at your repo

Before sideloading, the app needs to know which repo to read. Open `source/Config.brs` inside the unzipped project and edit these three lines:

```brightscript
githubUser: "YOUR_GITHUB_USERNAME"
githubRepo: "YOUR_REPO_NAME"
githubBranch: "main"
```

Then re-zip the project (see below) — or just tell me your repo's username/name and I'll do this and re-zip it for you.

**Re-zipping:** the `manifest` file must sit at the *root* of the zip, not inside a subfolder.

```bash
cd church-signage-roku
zip -r church-signage.zip manifest source components images
```

## 4. Enable Developer Mode on the Roku

On the Roku remote, press: **Home ×3, Up ×2, Right, Left, Right, Left, Right.**

A screen appears with a web address (something like `http://192.168.1.xxx`). Accept the Developer Tools License Agreement and set a password — you'll need it in a second. The Roku reboots into developer mode.

## 5. Sideload the app

1. On a computer on the **same Wi-Fi/network** as the Roku, open the address shown on the TV in step 4.
2. Log in — username `rokudev`, password whatever you just set.
3. Click **Upload**, choose **zip**, and select `church-signage.zip`.
4. The app installs and launches. You should see the splash screen, then it'll start loading content from GitHub within a few seconds.

To update the app later (rare — only if you change Config.brs or the code itself), just sideload the new zip the same way; it replaces the old one.

## 6. Leave it running

Switch the TV to the Roku's input and leave the Church Signage channel open. Roku devices don't have a general "launch this app on boot" setting out of the box, so after a power cycle you may need to reopen the channel from the Roku home screen once. If this becomes a hassle, Roku's business/hospitality program offers auto-launch features worth looking into separately.

---

## Notes on how it behaves

- If the network hiccups or GitHub is briefly unreachable, the board keeps showing the last content it successfully loaded rather than going blank.
- Time windows use the Roku's local time zone (set during the Roku's own initial setup).
- A window like `22:00`–`06:00` (start later than end) is treated as spanning midnight.
- Changing content never requires touching the Roku — only changing *which repo* it reads from does.
