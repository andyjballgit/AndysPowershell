:: GitSynch.cmd 
:: Emualates what Visual Studio does
:: 1st param is the comments for the commit, if ommitted , just does a git status to show whats changed
:: Andy Ball 8/7/2017

@echo off 
If !%1==! goto error 

git add *.*
git status
git commit -a -m %1
git push

goto end

:error
@echo *** Usage : 
@echo     GitSynch "updated readme"
@echo.
@echo *** Current Git Status :
git status
goto end
:end