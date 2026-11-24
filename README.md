# Bookworm Adventures Deluxe Debug Menu

A battle debug menu for experimenting with letters, gems, health, potions, status effects, and treasures in Bookworm Adventures Deluxe.

## Install

1. Download or clone this repository and open a terminal in its folder.
2. Close Bookworm Adventures. Find the game folder containing `BookwormAdventures.exe` and `main.pak`. For Heroic, use the folder that contains the executable selected in the game's settings.
3. Run the installer with Python 3.10 or later, replacing the example path with your game folder.

   Linux

   ```sh
   python3 install.py "/path/to/Bookworm Adventures Deluxe"
   ```

   Windows

   ```powershell
   py -3 install.py "C:\Games\Bookworm Adventures Deluxe"
   ```

4. Launch the game normally, enter a turn-based battle, and press **F9** once you can select tiles.

Each player supplies their own game installation. The installer checks the original archive's checksum and saves a verified copy as `main.pak.bookworm-debug.original` beside the active archive. The mod was tested on Linux through Heroic with GE-Proton.

## Controls

| Key | Action |
| --- | --- |
| F9 | Open or close the menu |
| Esc | Close the menu |
| Up / Down | Choose a row |
| Left / Right | Change the selected value |
| Enter | Apply the selected control |
| PgUp / PgDn | Switch pages |

The **Board** page edits letters and letter bonuses, adds a selected gem, or places a **Random gem** on an occupied tile that has no gem. The **Battle** page changes Lex and opponent health, grants potions, applies or clears status effects, and equips treasures available in that battle.

## Restore or update

Close the game and run the installer with `--restore` to restore the original archive.

```sh
python3 install.py "/path/to/Bookworm Adventures Deluxe" --restore
```

On Windows, use `py -3` in place of `python3`. To update the mod, restore the original archive, download the new revision, and run the install command again.

## Publish to GitHub

Run `gh repo create` from the mod repository and choose to push an existing local repository. Select private visibility for personal use or public visibility to share it. The repository tracks the Lua source, installer, and documentation. [GitHub's publishing instructions](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)
