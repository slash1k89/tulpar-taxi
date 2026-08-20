@echo off
pushd "%~dp0"
"C:\Program Files\nodejs\npm.cmd" test
set TEST_EXIT=%ERRORLEVEL%
popd
exit /b %TEST_EXIT%
