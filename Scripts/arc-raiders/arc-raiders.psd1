@{
    # Display name used in banners/log output
    DisplayName  = 'ARC RAIDERS'

    # Process name (without .exe) that identifies the running game
    ProcessNames = @('PioneerGame')

    # 'Steam' launches via steam://rungameid/<SteamAppId>; 'Direct' launches ExePath
    LaunchType   = 'Steam'
    SteamAppId   = '1808500'
    ExePath      = 'C:\Program Files (x86)\Steam\steamapps\common\Arc Raiders\PioneerGame\Binaries\Win64\PioneerGame.exe'

    # Process priority applied once the game process is detected
    Priority     = 'High'
}
