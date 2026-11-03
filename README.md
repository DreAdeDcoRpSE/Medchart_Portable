# MedChart Portable

**A portable medical record organizer for Windows. Keep track of medications, doctors, and allergies, and print information for medical appointments.**

MedChart Portable is a locally run edition of MedChart. It uses **PHP 8.4 and SQLite**, starts its own local web server, and opens in your browser. You do **not** need to install WAMP, Apache, MySQL, or MariaDB.

Your medical records are stored on your computer, not uploaded to a cloud service by MedChart. Internet access is needed to download the PHP runtime on first launch (and for optional PHP updates), but everyday use is local.

> **Platform:** Windows. This is a portable local application, not a publicly accessible web server or a native Windows `.exe` application.

## Why I made MedChart


This script was designed and built out of a need.

My mother was diagnosed with cancer many years ago. Over the years, with all the treatments and doctor visits, it became a mess trying to keep track of her medications, doctors, allergies, and all the other information that almost every doctor asks for when you go in for an appointment. They want to make sure everything in their charts is up to date, and understandably so.

For a while, my mother kept handwritten notes, but that eventually became too much to keep up with. My sister then made a simple chart in Excel, which helped, but my mother wasn't comfortable making changes to it herself. So I took it upon myself to write something that would be easier for her to use.

The idea was pretty simple: keep everything in one place, make it easy to update, and have a button to print the information whenever she had an appointment. If needed, we could also create a PDF to send to a doctor's office.

Every doctor and nurse we've shown it to has loved the idea and appreciated having an organized, up-to-date list handed to them. It makes their job a little easier, and it saves us from having to write the same information out over and over again.

I've had a working version of MedChart running for my mother for about two years. After making the web version available, I wanted a version that people could run on their own Windows computer without setting up WAMP, MySQL, or a web-hosting account.

That's where MedChart Portable comes in. It uses a local database and launches in your browser, but it stays on your own computer. The encrypted Import/Export feature also makes it possible to transfer records between compatible MedChart installations.

## Screenshots


Screenshots below show the MedChart interface. Some may have been captured from the web edition; the portable edition uses the same general interface.

### Dashboard

The main page for viewing and managing your medical information.

<a href="https://github.com/user-attachments/assets/44b9fdc9-6dea-4594-a28a-c5192fd29b23">
  <img
    src="https://github.com/user-attachments/assets/44b9fdc9-6dea-4594-a28a-c5192fd29b23"
    alt="MedChart Dashboard"
    width="500"
  >
</a>

### Medications in action

Activate or deactivate medications and rearrange their order using drag-and-drop.

<a href="https://github.com/user-attachments/assets/b733d4da-b5c7-4a3d-9560-2af39c80f8f5">
  <img
    src="https://github.com/user-attachments/assets/b733d4da-b5c7-4a3d-9560-2af39c80f8f5"
    alt="MedChart medication management demonstration"
    width="500"
  >
</a>

### Mobile view

The responsive layout makes it possible to use MedChart on smaller screens.

<a href="https://github.com/user-attachments/assets/3e700fb9-2263-4df2-b3d9-7cf6bbbd3a69">
  <img
    src="https://github.com/user-attachments/assets/3e700fb9-2263-4df2-b3d9-7cf6bbbd3a69"
    alt="MedChart Mobile view"
    height="500"
  >
</a>

### Encrypted Import and Export

Move your medical information between compatible MedChart installations using password-protected transfer files.

<a href="https://github.com/user-attachments/assets/51a79ebe-60d8-4b8b-8978-36e048cd51d4">
  <img
    src="https://github.com/user-attachments/assets/51a79ebe-60d8-4b8b-8978-36e048cd51d4"
    alt="MedChart Import and Export page"
    height="500"
  >
</a>

### Admin Control Panel

Manage user accounts and application administration from the ACP.

<a href="https://github.com/user-attachments/assets/ac9eb053-58ab-4edc-ad41-7c9bee43cb15">
  <img
    src="https://github.com/user-attachments/assets/ac9eb053-58ab-4edc-ad41-7c9bee43cb15"
    alt="MedChart Admin Control Panel"
    height="500"
  >
</a>

### Printer-friendly page

A clean, printable summary you can take to an appointment or save as a PDF.

<a href="https://github.com/user-attachments/assets/f7a8b7a6-42c3-4f4a-889b-b225dccb0150">
  <img
    src="https://github.com/user-attachments/assets/f7a8b7a6-42c3-4f4a-889b-b225dccb0150"
    alt="MedChart printer-friendly medical summary"
    height="500"
  >
</a>

## Features


### Medical information

- **Medications:** Keep track of medication names, doses, and frequency. Mark medications active or inactive and arrange them in the order you prefer.
- **Allergies:** Maintain a list of allergies that can be included in your medical summary.
- **Medical team:** Keep a list of doctors and other healthcare providers, including their roles and phone numbers.
- **Patient information:** Store basic patient details and notes in one place.
- **Printer-friendly summary:** Print an organized list to bring to appointments.
- **PDF output:** Generate a PDF copy when you need a digital document.

### Accounts and administration

- Individual user accounts, with each account's medical records kept separate.
- Administrator controls for managing accounts and approvals.
- Account security features. Password-reset options may differ from the hosted web edition.
- Security event logging.
- Responsive interface with light, dark, and automatic theme options.

### Encrypted Import and Export

MedChart can export your medical information to a password-protected `.medchart` file and import it into another compatible installation.

- **Export:** Create an encrypted transfer file using a password or passphrase you choose.
- **Preview:** Review what an import contains before applying it.
- **Merge:** Add imported information while avoiding duplicate entries where supported.
- **Replace:** Replace the applicable existing medical information with the imported data.
- **Portable data:** The transfer file is encrypted independently of the web server's installation-specific encryption key.

**Important:** Keep your transfer password safe. If you forget it, MedChart cannot recover the contents of that encrypted transfer file. Treat exported files as sensitive, even though they are encrypted.

### Portable edition

- **Windows launcher:** Start and stop MedChart using the included `.cmd` files.
- **No separate database server:** Uses a local SQLite database instead of MySQL or MariaDB.
- **Encrypted medical data:** Sensitive medical records are encrypted at rest using an installation-specific key.
- **Local-only server:** The bundled launcher binds the application to `127.0.0.1`, so it is intended for use on the same computer.
- **Automatic PHP setup:** Downloads the required Windows PHP 8.4 runtime on first launch.
- **Optional PHP updates:** The launcher can check for newer PHP 8.4 builds and ask before updating; it does not silently jump to a new PHP major/minor series.
- **Portable installation:** Move the complete installed folder, including its database and encryption key, to another location or computer.

## Requirements

- A Windows computer (the supplied launcher uses Windows PowerShell).
- An internet connection **for the first launch**, to download the PHP 8.4 Windows runtime, unless the required runtime is already present.
- Permission to run the included `.cmd` and PowerShell launcher scripts and write files inside the extracted folder.
- A modern web browser.

**No WAMP, MySQL/MariaDB, or separate PHP installation is required.**

## Installing MedChart Portable

1. Download the **MedChart Portable** release ZIP and extract the entire archive to a folder of your choice, such as `C:\MedChart-Portable`.
2. Run **`Start_MedChart.cmd`** from the extracted folder.
3. On the first launch, allow the launcher to download PHP from the official PHP for Windows distribution site. This may take a moment.
4. When the local application opens in your browser, follow the first-time installer and create your administrator account.
5. Sign in and start adding your information.
6. When finished, use **`Stop_MedChart.cmd`** to stop the local server.

On later launches, run `Start_MedChart.cmd` again. Your existing database and records will be reused.

> **Important:** Extract the **entire ZIP** before running it. Do not launch the application directly from inside the ZIP archive.

### Where your information is stored

| Location | Purpose |
| --- | --- |
| `data/medchart.sqlite` | Local SQLite database containing your records |
| `data/sessions/` | Temporary PHP session files |
| `medchart/secret/database.php` | Generated local database configuration |
| `medchart/secret/secret.php` | Generated installation-specific encryption key |
| `medchart/secret/installed.lock` | Marks installation as completed |
| `runtime/php/` | Downloaded PHP runtime |
| `logs/` | Local diagnostic logs |

The installer creates the database configuration, encryption key, and installation marker during setup. **They are not supposed to be pre-filled in a clean distribution.**

### Backing up or moving MedChart Portable

1. Stop MedChart first using `Stop_MedChart.cmd`.
2. Copy the **complete MedChart Portable folder** to your backup drive or new location, including `data/` and `medchart/secret/`.
3. Start MedChart from the copied folder and verify that your records are accessible.

**Do not lose or replace `medchart/secret/secret.php`.** Your existing encrypted medical records depend on that key. A copy of the database alone is not a complete recoverable backup.

You can also use the application's encrypted **Import / Export** feature to transfer medical information between compatible MedChart installations.

## Using MedChart

After signing in, enter your patient information, medications, allergies, and medical team details. Update the lists whenever something changes, then use the printer-friendly page or PDF feature for appointments.

For transfers, open **Import / Export**. Review the import preview and choose carefully between **Merge** and **Replace**. Back up your current information before using Replace.

## Security and privacy

MedChart Portable runs a local web server bound to **`127.0.0.1` (localhost)**. It is not designed to be exposed to your local network or the public internet.

- Medical records are stored locally in SQLite; sensitive record fields are encrypted at rest.
- Passwords are stored as password hashes, not readable passwords.
- Each account's records are kept separate by the application.
- Use strong, unique passwords and keep your Windows account secure.
- Back up both your SQLite database **and** the installation-specific encryption key.
- Protect exported `.medchart` files and their passphrases.
- Keep Windows and the downloaded PHP runtime updated.
- Do not post real medical records, database files, encryption keys, or passwords in public GitHub issues.

**Local storage does not automatically protect against someone who already has access to your Windows account or computer.** Use appropriate device security and secure backups.

MedChart is a personal record-keeping tool. **It is not an electronic health record system for clinical use, a medical device, or a substitute for medical advice.** Always verify medication and allergy information with your healthcare professionals.

## PHP runtime and updates

The launcher downloads a compatible **PHP 8.4 Windows runtime** when needed. It can check for newer releases within the PHP 8.4 series and offer an optional update. If you decline an update, the installed runtime remains in use. The updater is intended to preserve the local configuration and recover from an unsuccessful update.

An internet connection is not required for normal day-to-day use once PHP is installed. The local PHP server must be running while you use MedChart.

## Portable vs. web edition

| MedChart Portable | MedChart web edition |
| --- | --- |
| Runs on a Windows computer | Runs on a compatible PHP web server |
| SQLite database | MySQL / MariaDB database |
| Local browser access via `127.0.0.1` | Access depends on how the web server is configured |
| PHP downloaded and managed by the launcher | PHP and server environment managed by the host or administrator |
| No separate web-server setup | Requires web-server and database setup |

The encrypted `.medchart` import/export format is intended for transferring records between compatible editions.

## ❤️ Support MedChart

MedChart is a free project that I develop and maintain in my spare time.

If you find MedChart useful and would like to support its continued development, you can make a donation through PayPal. Donations are completely optional, but they're always appreciated and help keep the project going.

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-0070BA?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.com/donate/?hosted_button_id=PTAZ2DD7CTDVG)

**Thank you for your support!**


## License

MedChart Portable is distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See the repository's `LICENSE` file for the full terms.

Third-party components, including Dompdf, retain their own copyright notices and licenses. Their license files should remain included with the distribution.

## Feedback and issues

If you find a bug or have an idea for improving MedChart, feel free to open an issue on GitHub. Please include the MedChart Portable version, Windows version, PHP version (if known), what you were doing, and any relevant error message—but **never include personal medical records, passwords, database credentials, or encryption keys**.

---

*MedChart started as a way to make one person's medical appointments a little easier. Hopefully it can do the same for others.*
