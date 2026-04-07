# Protonify

A native macOS desktop client for [Proton Pass](https://proton.me/pass), built with Flutter.

## Features

- Browse and search all your Proton Pass vaults and items
- View logins, notes, credit cards, identities, aliases, and SSH keys
- Create and edit items directly from the app
- Copy passwords, usernames, and other fields with one click
- Menu bar mode -- run Protonify as a status bar icon with no Dock presence
- Light and dark theme support
- Transparent native titlebar with drag-to-move

## Download

### From Releases

Download the latest `.dmg` from the [Releases](../../releases) page, open it, and drag **Protonify.app** into your Applications folder.

### Build from source

Requires [Flutter](https://docs.flutter.dev/get-started/install) (3.11+) and Xcode.

```sh
git clone https://github.com/your-username/protonify.git
cd protonify
flutter build macos --release
```

The built app will be at `build/macos/Build/Products/Release/protonify.app`.

## Prerequisites

Protonify requires the [Proton Pass CLI](https://proton.me/pass/download) (`pass-cli`). The app will guide you through setup if it's not detected.

```sh
brew install protonpass/tap/pass-cli
pass-cli login
```

Alternatively, download `pass-cli` manually from [proton.me/pass/download](https://proton.me/pass/download) and place it at `~/.local/bin/pass-cli`.

## Usage

- **Search** -- Use the search bar at the top to filter items by title, username, or URL
- **Categories** -- Click a category in the left sidebar to filter by item type
- **Create** -- Click the `+` button in the item list header to add a new item
- **Edit** -- Click the pencil icon in the detail view to edit an existing item
- **Menu bar mode** -- Open Settings (gear icon) and toggle "Menu bar mode" to move the app from the Dock to the menu bar. Left-click the icon to show/hide the window; right-click to quit.

## License

[MIT](LICENSE)
