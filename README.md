# Bookworm Adventures Deluxe Debug Menu

A battle debug menu for experimenting with letters, gems, health, potions, status effects, and treasures in Bookworm Adventures Deluxe.

## Install

1. Download or clone this repository. If you downloaded a ZIP file, extract it first.
2. Open a command window in the mod folder. On Windows, open the folder in File Explorer, type `cmd` in the address bar, and press **Enter**.
3. Close Bookworm Adventures and find the game folder containing `BookwormAdventures.exe` and `main.pak`.
4. Run the installer with Python 3.10 or later. Replace the example path with your game folder.

   ```
   py -3 install.py "C:\Games\Bookworm Adventures Deluxe"
   ```

   If your Python command is `python3` or `python`, use it in place of `py -3`.

5. Launch the game normally, enter a turn-based battle, and press **F9** once you can select tiles.

Each player supplies their own game installation. The installer checks the original archive's checksum and saves a verified copy as `main.pak.bookworm-debug.original` beside the active archive.

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

Close the game, open a command window in the mod folder, and run the installer with `--restore`. Use the same Python command and game folder as during installation.

```
py -3 install.py "C:\Games\Bookworm Adventures Deluxe" --restore
```

To update the mod, restore the original archive, download the new revision, and run the install command again.

## Publish to GitHub

Run `gh repo create` from the mod repository and choose to push an existing local repository. Select private visibility for personal use or public visibility to share it. The repository tracks the Lua source, installer, and documentation. [GitHub's publishing instructions](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)
