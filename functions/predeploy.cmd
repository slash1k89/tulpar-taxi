@echo off
pushd "%~dp0"
call node_modules\.bin\eslint.cmd .
set "lintExitCode=%ERRORLEVEL%"
popd
exit /b %lintExitCode%
