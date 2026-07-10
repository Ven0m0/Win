@{
    # Display name used in banners/log output
    DisplayName  = 'ARC RAIDERS'

    # Process names (without .exe) that identify the running game
    ProcessNames = @('ARC', 'pioneergame', 'ARC-Win64-Shipping')

    # 'Steam' launches via steam://rungameid/<SteamAppId>; 'Direct' launches ExePath
    LaunchType   = 'Steam'
    SteamAppId   = '1808500'

    # Process priority applied once the game process is detected
    Priority     = 'High'
}
