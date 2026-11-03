# ATIB CLI

ATIB Online web banking in your Mac's Terminal: balances, transactions, cards and their statements,
beneficiaries, transfers (ATIB and LYPAY) and prepaid vouchers. It reads; a transfer, a new beneficiary, a voucher
or a card block goes through the bank's own review page and is sent only after you confirm it, with the bank's
code. Optional apps: your transactions recorded in Wallet App by BudgetBakers, and daily, weekly and monthly
summaries from a Telegram bot of yours, which can also answer `/balance` and `/last` while your Mac is awake.
`atib balance` shows your balances in Terminal.

Not made or supported by ATIB: it drives ATIB Online's own website in your own Google Chrome, the way you would.

## Install

You need macOS 12 or later and [Google Chrome](https://www.google.com/chrome/), dragged into Applications (not opened from the disk image it downloads as). Open Terminal and paste:

```
curl -fsSL https://raw.githubusercontent.com/alibenmussa/atib-cli-dist/main/install.sh | bash
```

No administrator password and nothing else to install: it adds uv (which brings its own Python) if it is missing,
then ATIB CLI. Then open a new Terminal window and type `atib`. The first time, sign in with the username and
password of the ATIB mobile app.

## Update

`atib update` installs the newest version; home tells you when there is one (Settings → Check for updates turns
that off). `atib update --to 0.2.0` goes back to an earlier version. Your sign-in, settings and apps stay as they
are.

## Where things are kept

- Your sign-in, and the Wallet App and Telegram tokens: in your Mac's Keychain (Keychain Access → `atib-cli`).
  Sign out (home → Sign out and close, or `atib stop`) forgets the sign-in.
- Everything else (settings, the background Chrome's profile, receipts, logs):
  `~/Library/Application Support/atib-cli`, readable by you alone. Receipts and exports can go to another folder
  (Settings → Receipts and files).
- Nothing is sent anywhere but to the bank, and to Wallet App or Telegram if you connect them.

A Mac shared with other people who could run programs as you is not a safe place for it.

## Remove

```
atib uninstall
```

It signs out, stops the background Chrome and services, and removes ATIB CLI; it asks before deleting your data
folder and Keychain items.
