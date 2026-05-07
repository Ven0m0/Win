- clean steam redist installers:
  ```text
  C:\Program Files (x86)\Steam\steamapps\common\Steamworks Shared\_CommonRedist\DirectX
  C:\Program Files (x86)\Steam\steamapps\common\Steamworks Shared\_CommonRedist\vcredist
  ```
- download [umpdc.dll](https://github.com/Aetopia/NoSteamWebHelper) to disable Steam's CEF/Chromium Embedded Framework. Move it to "C:\Program Files (x86)\Steam"
- Create desktop shortcut with these steam launch arguments: `"C:\Program Files (x86)\Steam\Steam.exe" -nofriendsui -nointro -nobigpicture -cef-single-process -cef-disable-breakpad -cef-disable-gpu-compositing -cef-disable-gpu -cef-disable-js-logging -noconsole +open steam://open/minigameslist`
- add [notepad replacer](https://www.binaryfortress.com/NotepadReplacer) to the package install (needs notepad++): "https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100"
- implement the install/bootstrap from https://github.com/chawyehsu/dotfiles/blob/main/install.ps1 https://github.com/chawyehsu/dotfiles
- implement features from https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1 https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json
