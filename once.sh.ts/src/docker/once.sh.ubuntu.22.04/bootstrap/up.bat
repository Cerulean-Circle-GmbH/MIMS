@echo off 

set DOCKER_COMPOSE_FILE=%1%
if "%DOCKER_COMPOSE_FILE%"=="" ( echo "%0% <docker-compose-file>"
) else (
    docker-compose -f %DOCKER_COMPOSE_FILE% -p once up
)
