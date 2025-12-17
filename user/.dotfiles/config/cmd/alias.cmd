@echo off
:: https://github.com/excalith/.dotfiles/blob/main/config/cmd/alias.cmd
:: Commands

DOSKEY ls=dir /B $*
DOSKEY mkcd="%USERPROFILE%\.dotfiles\config\cmd\mkcd.bat" $*
DOSKEY touch="%USERPROFILE%\.dotfiles\config\cmd\touch.bat" $*
DOSKEY clear=cls
DOSKEY cat=bat $*
DOSKEY nano=micro $*

:: Common directories

DOSKEY dotfiles=cd "%USERPROFILE%\.dotfiles\$*"


:: Easy navigation

DOSKEY ..=cd ..
DOSKEY ...=cd ../..
DOSKEY ....=cd ../../..
DOSKEY .....=cd ../../../..
