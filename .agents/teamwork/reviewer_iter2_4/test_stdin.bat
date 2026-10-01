@echo off
set "ROOT_OUTPUT=uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0"
echo "%ROOT_OUTPUT%" | findstr /c:"uid=0(root)" >nul
echo Positive match errorlevel: %errorlevel%
if %errorlevel% equ 0 (
    echo POSITIVE_SUCCESS
) else (
    echo POSITIVE_FAILED
)
