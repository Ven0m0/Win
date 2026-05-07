- clean steam redist installers:
  ```text
  C:\Program Files (x86)\Steam\steamapps\common\Steamworks Shared\_CommonRedist\DirectX
  C:\Program Files (x86)\Steam\steamapps\common\Steamworks Shared\_CommonRedist\vcredist
  ```
- download [umpdc.dll](https://github.com/Aetopia/NoSteamWebHelper) to disable Steam's CEF/Chromium Embedded Framework. Move it to "C:\Program Files (x86)\Steam"
- Create desktop shortcut with these steam launch arguments: `"C:\Program Files (x86)\Steam\Steam.exe" -nofriendsui -nointro -nobigpicture -cef-single-process -cef-disable-breakpad -cef-disable-gpu-compositing -cef-disable-gpu -cef-disable-js-logging -noconsole +open steam://open/minigameslist`
